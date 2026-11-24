//! Explorer JSON Lines v2 backend.
use serde_json::{json, Value};
use std::cmp::Ordering;
use std::fs;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};

fn event(kind: &str, data: Value) -> Value {
    json!({"version": 2, "type": kind, "data": data})
}

fn natural_cmp_chars(a: &[char], b: &[char]) -> Ordering {
    let (mut i, mut j) = (0, 0);
    while i < a.len() && j < b.len() {
        if a[i].is_ascii_digit() && b[j].is_ascii_digit() {
            let (mut end_a, mut end_b) = (i, j);
            while end_a < a.len() && a[end_a].is_ascii_digit() {
                end_a += 1;
            }
            while end_b < b.len() && b[end_b].is_ascii_digit() {
                end_b += 1;
            }
            let (mut sig_a, mut sig_b) = (i, j);
            while sig_a < end_a && a[sig_a] == '0' {
                sig_a += 1;
            }
            while sig_b < end_b && b[sig_b] == '0' {
                sig_b += 1;
            }
            let order = (end_a - sig_a)
                .cmp(&(end_b - sig_b))
                .then_with(|| a[sig_a..end_a].cmp(&b[sig_b..end_b]));
            if order != Ordering::Equal {
                return order;
            }
            i = end_a;
            j = end_b;
        } else {
            let order = a[i].cmp(&b[j]);
            if order != Ordering::Equal {
                return order;
            }
            i += 1;
            j += 1;
        }
    }
    (a.len() - i).cmp(&(b.len() - j))
}

fn list(data: &Value) -> Result<Value, String> {
    if !data.is_null() && !data.is_object() {
        return Err("data debe ser un objeto".into());
    }
    let path = match data.get("path") {
        None => "",
        Some(Value::String(s)) => s,
        _ => return Err("path debe ser una cadena".into()),
    };
    let show_hidden = match data.get("showHidden") {
        None => false,
        Some(Value::Bool(b)) => *b,
        _ => return Err("showHidden debe ser booleano".into()),
    };
    let path = if path.is_empty() {
        PathBuf::from(std::env::var_os("HOME").ok_or("HOME no está definido")?)
    } else {
        PathBuf::from(path)
    };
    if !path.is_absolute() {
        return Err("path debe ser absoluto".into());
    }
    let path = fs::canonicalize(&path).map_err(|e| format!("{}: {e}", path.display()))?;
    let path_str = path.to_str().ok_or("La ruta no es UTF-8")?;
    let parent = path
        .parent()
        .map(Path::to_str)
        .unwrap_or(Some(""))
        .ok_or("La ruta padre no es UTF-8")?;
    let mut entries = Vec::new();
    let mut skipped = 0usize;
    for item in fs::read_dir(&path).map_err(|e| format!("{path_str}: {e}"))? {
        let item = match item {
            Ok(item) => item,
            Err(_) => {
                skipped += 1;
                continue;
            }
        };
        let name = match item.file_name().into_string() {
            Ok(name) => name,
            Err(_) => {
                skipped += 1;
                continue;
            }
        };
        if !show_hidden && name.starts_with('.') {
            continue;
        }
        let entry_path = item.path();
        // metadata follows symlinks, and never opens FIFOs or other special files.
        let metadata = match fs::metadata(&entry_path) {
            Ok(metadata) => metadata,
            Err(_) => {
                skipped += 1;
                continue;
            }
        };
        if !metadata.is_dir() && !metadata.is_file() {
            continue;
        }
        let entry_path = match entry_path.to_str() {
            Some(path) => path,
            None => {
                skipped += 1;
                continue;
            }
        };
        let sort_name: Vec<char> = name.to_lowercase().chars().collect();
        entries.push((
            metadata.is_dir(),
            name,
            entry_path.to_owned(),
            metadata.len(),
            sort_name,
        ));
    }
    entries.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then_with(|| natural_cmp_chars(&a.4, &b.4))
            .then_with(|| a.1.cmp(&b.1))
    });
    let entries: Vec<Value> = entries
        .into_iter()
        .map(|(is_dir, name, path, size, _)| {
            json!({
                "name": name, "path": path, "isDir": is_dir, "isFile": !is_dir, "size": size
            })
        })
        .collect();
    Ok(
        json!({"path": path_str, "parent": parent, "entries": entries, "showHidden": show_hidden, "skipped": skipped}),
    )
}

fn handle(line: &str, ping_count: &mut u64) -> Value {
    let result = (|| -> Result<Value, String> {
        let command: Value =
            serde_json::from_str(line).map_err(|e| format!("JSON inválido: {e}"))?;
        if command.get("version").and_then(Value::as_u64) != Some(2) {
            return Err("Versión de protocolo no soportada (se requiere version: 2)".into());
        }
        match command.get("type").and_then(Value::as_str) {
            Some("app.check") => Ok(event("app.checked", json!({"ok": true, "engine": "rust"}))),
            Some("app.ping") => {
                *ping_count += 1;
                Ok(event(
                    "app.pong",
                    json!({"count": *ping_count, "message": format!("Motor Rust respondió al pulso #{} en tiempo real.", ping_count)}),
                ))
            }
            Some("fs.list") => Ok(event(
                "fs.listed",
                list(command.get("data").unwrap_or(&Value::Null))?,
            )),
            _ => Err("Acción no reconocida por el motor Rust".into()),
        }
    })();
    result.unwrap_or_else(|message| event("error", json!({"message": message})))
}

fn emit(out: &mut impl Write, value: &Value) -> io::Result<()> {
    serde_json::to_writer(&mut *out, value)?;
    writeln!(out)?;
    out.flush()
}

fn process_stream<R: BufRead, W: Write>(mut input: R, mut out: W) -> io::Result<()> {
    let mut ping_count = 0;
    let mut buf = Vec::new();
    loop {
        buf.clear();
        if input.read_until(b'\n', &mut buf)? == 0 {
            return Ok(());
        }
        match std::str::from_utf8(&buf) {
            Ok(line) if line.trim().is_empty() => {}
            Ok(line) => emit(&mut out, &handle(line, &mut ping_count))?,
            Err(_) => emit(
                &mut out,
                &event("error", json!({"message": "Entrada no es UTF-8 válida"})),
            )?,
        }
    }
}

fn main() -> io::Result<()> {
    let mut out = io::stdout().lock();
    emit(
        &mut out,
        &event(
            "app.ready",
            json!({"name": "Explorer", "version": env!("CARGO_PKG_VERSION"), "engine": "rust"}),
        ),
    )?;
    process_stream(io::stdin().lock(), &mut out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    static NEXT: AtomicUsize = AtomicUsize::new(0);
    struct Temp(PathBuf);
    impl Temp {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!(
                "explorer-test-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&path).unwrap();
            Self(path)
        }
    }
    impl Drop for Temp {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn listing_order_hidden_and_escaping() {
        let temp = Temp::new();
        fs::create_dir(temp.0.join("z dir")).unwrap();
        fs::write(temp.0.join("a\"\n.txt"), b"abc").unwrap();
        fs::write(temp.0.join(".hidden"), b"").unwrap();
        let result = list(&json!({"path": temp.0, "showHidden": false})).unwrap();
        assert_eq!(result["entries"].as_array().unwrap().len(), 2);
        assert_eq!(result["entries"][0]["name"], "z dir");
        assert_eq!(result["entries"][1]["name"], "a\"\n.txt");
        assert_eq!(result["entries"][1]["size"], 3);
        assert_eq!(result["parent"], temp.0.parent().unwrap().to_str().unwrap());
        assert_eq!(
            list(&json!({"path": temp.0, "showHidden": true})).unwrap()["entries"]
                .as_array()
                .unwrap()
                .len(),
            3
        );
        assert_eq!(
            serde_json::from_str::<Value>(&result.to_string()).unwrap(),
            result
        );
    }

    #[test]
    fn errors_and_protocol_are_recoverable() {
        let mut count = 0;
        assert_eq!(handle("not json", &mut count)["type"], "error");
        assert_eq!(
            handle(
                r#"{"version":2,"type":"fs.list","data":{"path":"relative"}}"#,
                &mut count
            )["type"],
            "error"
        );
        assert_eq!(
            handle(
                r#"{"version":2,"type":"fs.list","data":{"showHidden":"yes"}}"#,
                &mut count
            )["type"],
            "error"
        );
        assert_eq!(
            handle(r#"{"version":2,"type":"app.check"}"#, &mut count)["type"],
            "app.checked"
        );
        assert_eq!(
            handle(r#"{"version":2,"type":"app.ping"}"#, &mut count)["data"]["count"],
            1
        );
        assert_eq!(list(&json!({"path":"/"})).unwrap()["parent"], "");
    }

    #[test]
    fn version_and_invalid_utf8_recover_in_stream() {
        let input = b"{\"type\":\"app.check\"}\n{\"version\":1,\"type\":\"app.check\"}\n\xff\n  \n{\"version\":2,\"type\":\"app.ping\"}\n";
        let mut output = Vec::new();
        process_stream(&input[..], &mut output).unwrap();
        let events: Vec<Value> = std::str::from_utf8(&output)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(events.len(), 4);
        for e in &events[..2] {
            assert_eq!(
                e["data"]["message"],
                "Versión de protocolo no soportada (se requiere version: 2)"
            );
            assert_eq!(e["type"], "error");
        }
        assert_eq!(events[2]["type"], "error");
        assert_eq!(events[3]["type"], "app.pong");
        assert_eq!(events[3]["data"]["count"], 1);
    }

    #[test]
    fn stream_crlf_and_final_command_without_newline() {
        let input =
            b"{\"version\":2,\"type\":\"app.ping\"}\r\n{\"version\":2,\"type\":\"app.ping\"}";
        let mut output = Vec::new();
        process_stream(&input[..], &mut output).unwrap();
        let events: Vec<Value> = std::str::from_utf8(&output)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(events.len(), 2);
        assert_eq!(events[0]["type"], "app.pong");
        assert_eq!(events[0]["data"]["count"], 1);
        assert_eq!(events[1]["type"], "app.pong");
        assert_eq!(events[1]["data"]["count"], 2);
    }

    #[test]
    fn non_integer_version_is_rejected() {
        let response = handle(r#"{"version":2.0,"type":"app.check"}"#, &mut 0);
        assert_eq!(response["type"], "error");
        assert_eq!(
            response["data"]["message"],
            "Versión de protocolo no soportada (se requiere version: 2)"
        );
    }

    #[test]
    fn natural_order_very_long_numbers() {
        let compare = |a: &str, b: &str| {
            natural_cmp_chars(
                &a.chars().collect::<Vec<_>>(),
                &b.chars().collect::<Vec<_>>(),
            )
        };
        let max = "340282366920938463463374607431768211455";
        let above = "340282366920938463463374607431768211456";
        let larger = "1000000000000000000000000000000000000000";
        assert_eq!(compare(max, above), std::cmp::Ordering::Less);
        assert_eq!(compare(above, larger), std::cmp::Ordering::Less);
        assert_eq!(
            compare(&format!("000{above}"), above),
            std::cmp::Ordering::Equal
        );
        assert_eq!(
            compare(&format!("000{above}"), &format!("00{larger}")),
            std::cmp::Ordering::Less
        );
    }

    #[test]
    fn natural_order_directories_and_ties() {
        let temp = Temp::new();
        for name in ["dir10", "dir2"] {
            fs::create_dir(temp.0.join(name)).unwrap();
        }
        for name in [
            "gamma",
            "Beta",
            "alpha",
            "archivo10",
            "archivo2",
            "ALPHA",
            "archivo02",
        ] {
            fs::write(temp.0.join(name), b"").unwrap();
        }
        let result = list(&json!({"path": temp.0})).unwrap();
        let names: Vec<&str> = result["entries"]
            .as_array()
            .unwrap()
            .iter()
            .map(|entry| entry["name"].as_str().unwrap())
            .collect();
        assert_eq!(
            names,
            [
                "dir2",
                "dir10",
                "ALPHA",
                "alpha",
                "archivo02",
                "archivo2",
                "archivo10",
                "Beta",
                "gamma"
            ]
        );
    }

    #[cfg(unix)]
    #[test]
    fn symlinks_special_files_and_non_utf8() {
        use std::os::unix::{ffi::OsStringExt, fs::symlink, net::UnixListener};
        let temp = Temp::new();
        fs::create_dir(temp.0.join("dir")).unwrap();
        fs::write(temp.0.join("file"), b"abc").unwrap();
        symlink(temp.0.join("dir"), temp.0.join("link-dir")).unwrap();
        symlink(temp.0.join("file"), temp.0.join("link-file")).unwrap();
        let _socket = UnixListener::bind(temp.0.join("socket")).unwrap();
        let result = list(&json!({"path":temp.0})).unwrap();
        let entries = result["entries"].as_array().unwrap();
        assert_eq!(entries.len(), 4);
        assert!(entries
            .iter()
            .any(|e| e["name"] == "link-dir" && e["isDir"] == true));
        assert!(entries
            .iter()
            .any(|e| e["name"] == "link-file" && e["size"] == 3));
        fs::write(temp.0.join(std::ffi::OsString::from_vec(vec![0xff])), b"").unwrap();
        symlink(temp.0.join("missing"), temp.0.join("broken")).unwrap();
        let result = list(&json!({"path":temp.0})).unwrap();
        assert_eq!(result["skipped"], 2);
        assert_eq!(result["entries"].as_array().unwrap().len(), 4);
        assert!(list(&json!({"path":temp.0.join("missing")})).is_err());
    }
}
