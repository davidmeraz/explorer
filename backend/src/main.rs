//! Explorer JSON Lines v2 backend.
use serde_json::{json, Value};
use std::fs;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};

fn event(kind: &str, data: Value) -> Value {
    json!({"version": 2, "type": kind, "data": data})
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
        entries.push((
            metadata.is_dir(),
            name,
            entry_path.to_owned(),
            metadata.len(),
        ));
    }
    entries.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| a.1.cmp(&b.1)));
    let entries: Vec<Value> = entries
        .into_iter()
        .map(|(is_dir, name, path, size)| {
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

fn main() -> io::Result<()> {
    let mut out = io::stdout().lock();
    emit(
        &mut out,
        &event(
            "app.ready",
            json!({"name": "Explorer", "version": env!("CARGO_PKG_VERSION"), "engine": "rust"}),
        ),
    )?;
    let mut ping_count = 0;
    for line in io::stdin().lock().lines() {
        let line = line?;
        if !line.trim().is_empty() {
            emit(&mut out, &handle(&line, &mut ping_count))?;
        }
    }
    Ok(())
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
            fs::remove_dir_all(&self.0).unwrap();
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
                r#"{"type":"fs.list","data":{"path":"relative"}}"#,
                &mut count
            )["type"],
            "error"
        );
        assert_eq!(
            handle(
                r#"{"type":"fs.list","data":{"showHidden":"yes"}}"#,
                &mut count
            )["type"],
            "error"
        );
        assert_eq!(
            handle(r#"{"type":"app.check"}"#, &mut count)["type"],
            "app.checked"
        );
        assert_eq!(
            handle(r#"{"type":"app.ping"}"#, &mut count)["data"]["count"],
            1
        );
        assert_eq!(list(&json!({"path":"/"})).unwrap()["parent"], "");
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
