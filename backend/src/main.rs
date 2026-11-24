//! Explorer JSON Lines v2 backend.
use serde_json::{json, Value};
use std::cmp::Ordering;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::UNIX_EPOCH;

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
    let sort_by = match data.get("sortBy") {
        None => "name",
        Some(Value::String(s)) if ["name", "size", "mtime", "type"].contains(&s.as_str()) => s,
        _ => return Err("sortBy debe ser name, size, mtime o type".into()),
    };
    let sort_desc = match data.get("sortDesc") {
        None => false,
        Some(Value::Bool(b)) => *b,
        _ => return Err("sortDesc debe ser booleano".into()),
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
        let extension: Vec<char> = if !metadata.is_dir() {
            name.rfind('.')
                .filter(|&i| i > 0)
                .map(|i| name[i + 1..].to_lowercase())
                .unwrap_or_default()
        } else {
            String::new()
        }
        .chars()
        .collect();
        let mtime = metadata
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map_or(0, |d| d.as_secs());
        entries.push((
            metadata.is_dir(),
            name,
            entry_path.to_owned(),
            metadata.len(),
            sort_name,
            mtime,
            extension,
        ));
    }
    entries.sort_by(|a, b| {
        b.0.cmp(&a.0).then_with(|| {
            let name_order = || natural_cmp_chars(&a.4, &b.4).then_with(|| a.1.cmp(&b.1));
            if sort_by == "name" {
                let order = name_order();
                return if sort_desc { order.reverse() } else { order };
            }
            let primary = match sort_by {
                "size" if !a.0 => a.3.cmp(&b.3),
                "mtime" => a.5.cmp(&b.5),
                "type" => natural_cmp_chars(&a.6, &b.6),
                _ => Ordering::Equal,
            };
            (if sort_desc {
                primary.reverse()
            } else {
                primary
            })
            .then_with(name_order)
        })
    });
    let entries: Vec<Value> = entries
        .into_iter()
        .map(|(is_dir, name, path, size, _, mtime, _)| {
            json!({
                "name": name, "path": path, "isDir": is_dir, "isFile": !is_dir, "size": size, "mtime": mtime
            })
        })
        .collect();
    Ok(
        json!({"path": path_str, "parent": parent, "entries": entries, "showHidden": show_hidden, "skipped": skipped, "sortBy": sort_by, "sortDesc": sort_desc}),
    )
}

fn places_with_env(
    home: Option<&Path>,
    config: Option<&Path>,
    data: Option<&Path>,
    media: Option<&Path>,
) -> Value {
    let mut result = Vec::new();
    let mut seen = HashSet::new();
    let mut add = |name: &str, path: &Path, kind: &str| {
        if !path.is_absolute() {
            return;
        }
        if let Ok(canonical) = fs::canonicalize(path) {
            if canonical.is_dir() && canonical.to_str().is_some() && seen.insert(canonical.clone())
            {
                result.push(json!({"name": name, "path": canonical, "kind": kind}));
            }
        }
    };
    if let Some(home) = home {
        add("Inicio", home, "home");
        let config = config
            .map(Path::to_path_buf)
            .unwrap_or_else(|| home.join(".config"));
        let mut dirs = HashMap::new();
        if let Ok(contents) = fs::read_to_string(config.join("user-dirs.dirs")) {
            for line in contents.lines() {
                let line = line.trim();
                if line.starts_with('#') {
                    continue;
                }
                if let Some((key, value)) = line.split_once('=') {
                    let value = value.trim();
                    if value.starts_with('"') && value.ends_with('"') && value.len() >= 2 {
                        let mut decoded = String::new();
                        let mut chars = value[1..value.len() - 1].chars().peekable();
                        while let Some(c) = chars.next() {
                            if c == '\\' && matches!(chars.peek(), Some('"' | '\\')) {
                                decoded.push(chars.next().unwrap());
                            } else {
                                decoded.push(c);
                            }
                        }
                        let path = if decoded == "$HOME" {
                            home.to_path_buf()
                        } else if let Some(rest) = decoded.strip_prefix("$HOME/") {
                            home.join(rest)
                        } else {
                            PathBuf::from(decoded)
                        };
                        dirs.insert(key.trim().to_owned(), path);
                    }
                }
            }
        }
        for (key, name, kind, en, es) in [
            (
                "XDG_DESKTOP_DIR",
                "Escritorio",
                "desktop",
                "Desktop",
                "Escritorio",
            ),
            (
                "XDG_DOCUMENTS_DIR",
                "Documentos",
                "documents",
                "Documents",
                "Documentos",
            ),
            (
                "XDG_DOWNLOAD_DIR",
                "Descargas",
                "downloads",
                "Downloads",
                "Descargas",
            ),
            (
                "XDG_PICTURES_DIR",
                "Imágenes",
                "pictures",
                "Pictures",
                "Imágenes",
            ),
            ("XDG_MUSIC_DIR", "Música", "music", "Music", "Música"),
            ("XDG_VIDEOS_DIR", "Vídeos", "videos", "Videos", "Vídeos"),
        ] {
            if let Some(path) = dirs.get(key) {
                add(name, path, kind);
            } else if let Some(path) = [home.join(en), home.join(es)].iter().find(|p| p.is_dir()) {
                add(name, path, kind);
            }
        }
        let data = data
            .map(Path::to_path_buf)
            .unwrap_or_else(|| home.join(".local/share"));
        add("Papelera", &data.join("Trash/files"), "trash");
    } else if let Some(data) = data {
        add("Papelera", &data.join("Trash/files"), "trash");
    }
    add("Sistema", Path::new("/"), "root");
    if let Some(media) = media {
        if let Ok(items) = fs::read_dir(media) {
            let mut items: Vec<_> = items
                .flatten()
                .filter_map(|item| {
                    item.file_name()
                        .into_string()
                        .ok()
                        .map(|name| (name, item.path()))
                })
                .collect();
            items.sort_by(|a, b| {
                natural_cmp_chars(
                    &a.0.to_lowercase().chars().collect::<Vec<_>>(),
                    &b.0.to_lowercase().chars().collect::<Vec<_>>(),
                )
                .then_with(|| a.0.cmp(&b.0))
            });
            for (name, path) in items {
                add(&name, &path, "mount");
            }
        }
    }
    json!({"places": result})
}

fn places(data: &Value) -> Result<Value, String> {
    if !data.is_null() && !data.is_object() {
        return Err("data debe ser un objeto".into());
    }
    let home = std::env::var_os("HOME")
        .filter(|s| !s.is_empty())
        .map(PathBuf::from);
    let config = std::env::var_os("XDG_CONFIG_HOME")
        .filter(|s| !s.is_empty())
        .map(PathBuf::from);
    let data = std::env::var_os("XDG_DATA_HOME")
        .filter(|s| !s.is_empty())
        .map(PathBuf::from);
    let media = std::env::var("USER")
        .ok()
        .filter(|s| !s.is_empty() && s != "." && s != ".." && !s.contains('/'))
        .map(|s| Path::new("/run/media").join(s));
    Ok(places_with_env(
        home.as_deref(),
        config.as_deref(),
        data.as_deref(),
        media.as_deref(),
    ))
}

fn validate_entry_name(name: &str) -> Result<(), String> {
    if name.trim().is_empty() || name == "." || name == ".." || name.contains(['/', '\0']) {
        return Err("Nombre de elemento inválido".into());
    }
    Ok(())
}

fn directory(raw: &str) -> Result<PathBuf, String> {
    if raw.is_empty() || raw.contains('\0') || !Path::new(raw).is_absolute() {
        return Err("La ruta debe ser absoluta y válida".into());
    }
    let path = fs::canonicalize(raw).map_err(|e| e.to_string())?;
    if !path.is_dir() {
        return Err("La ruta no es un directorio".into());
    }
    Ok(path)
}

fn resolve_entry_path(raw: &str) -> Result<(PathBuf, PathBuf, String), String> {
    let path = Path::new(raw);
    if raw.is_empty() || raw.contains('\0') || !path.is_absolute() {
        return Err("La ruta debe ser absoluta y válida".into());
    }
    let name = path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or("Nombre inválido")?
        .to_owned();
    validate_entry_name(&name)?;
    let parent = directory(
        path.parent()
            .and_then(Path::to_str)
            .ok_or("Directorio padre inválido")?,
    )?;
    let src = parent.join(&name);
    fs::symlink_metadata(&src).map_err(|e| e.to_string())?;
    Ok((parent, src, name))
}

fn copy_entry_recursive(src: &Path, dst: &Path) -> io::Result<()> {
    let meta = fs::symlink_metadata(src)?;
    if meta.file_type().is_symlink() {
        std::os::unix::fs::symlink(fs::read_link(src)?, dst)
    } else if meta.is_file() {
        fs::copy(src, dst).map(|_| ())
    } else if meta.is_dir() {
        fs::create_dir(dst)?;
        for entry in fs::read_dir(src)? {
            let entry = entry?;
            copy_entry_recursive(&entry.path(), &dst.join(entry.file_name()))?;
        }
        Ok(())
    } else {
        Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Archivo especial no admitido",
        ))
    }
}

fn remove_entry(path: &Path) -> io::Result<()> {
    if fs::symlink_metadata(path)?.is_dir() {
        fs::remove_dir_all(path)
    } else {
        fs::remove_file(path)
    }
}

fn move_entry(src: &Path, dst: &Path) -> io::Result<()> {
    match fs::rename(src, dst) {
        Err(e) if e.raw_os_error() == Some(18) => {
            if let Err(e) = copy_entry_recursive(src, dst) {
                let _ = remove_entry(dst);
                return Err(e);
            }
            if let Err(e) = remove_entry(src) {
                return Err(io::Error::new(
                    e.kind(),
                    format!(
                        "La copia quedó en {} pero no se pudo eliminar el origen {}: {e}",
                        dst.display(),
                        src.display()
                    ),
                ));
            }
            Ok(())
        }
        result => result,
    }
}

fn encoded_path(path: &Path) -> String {
    use std::os::unix::ffi::OsStrExt;
    let mut result = String::new();
    for &b in path.as_os_str().as_bytes() {
        if b.is_ascii_alphanumeric() || b"-._~/".contains(&b) {
            result.push(b as char);
        } else {
            result.push_str(&format!("%{b:02X}"));
        }
    }
    result
}

fn deletion_date() -> String {
    let seconds = std::time::SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let z = (seconds / 86400) as i64 + 719468;
    let era = z / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let mut year = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = mp + if mp < 10 { 3 } else { -9 };
    year += i64::from(month <= 2);
    let t = seconds % 86400;
    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}",
        t / 3600,
        t / 60 % 60,
        t % 60
    )
}

fn trash_with_data_dir(raw_path: &str, data_home: &Path) -> Result<Value, String> {
    let (parent, src, name) = resolve_entry_path(raw_path)?;
    let trash = data_home.join("Trash");
    fs::create_dir_all(trash.join("files")).map_err(|e| e.to_string())?;
    fs::create_dir_all(trash.join("info")).map_err(|e| e.to_string())?;
    let trash = fs::canonicalize(trash).map_err(|e| e.to_string())?;
    if src == trash || trash.starts_with(&src) {
        return Err("No se puede enviar la papelera o sus ancestros a la papelera".into());
    }
    if src.starts_with(&trash) {
        return Err("El elemento ya está en la papelera".into());
    }
    for n in 1u64.. {
        let candidate = if n == 1 {
            name.clone()
        } else {
            format!("{name}.{n}")
        };
        let dest = trash.join("files").join(&candidate);
        if fs::symlink_metadata(&dest).is_ok() {
            continue;
        }
        let info = trash.join("info").join(format!("{candidate}.trashinfo"));
        let mut file = match fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&info)
        {
            Ok(file) => file,
            Err(e) if e.kind() == io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(e.to_string()),
        };
        if fs::symlink_metadata(&dest).is_ok() {
            let _ = fs::remove_file(&info);
            continue;
        }
        let result = writeln!(
            file,
            "[Trash Info]\nPath={}\nDeletionDate={}",
            encoded_path(&src),
            deletion_date()
        )
        .and_then(|_| move_entry(&src, &dest));
        if let Err(e) = result {
            if fs::symlink_metadata(&dest).is_err() {
                let _ = fs::remove_file(&info);
            }
            return Err(e.to_string());
        }
        return Ok(event(
            "fs.mutated",
            json!({"action":"trash", "path":src, "targetPath":dest, "parent":parent}),
        ));
    }
    unreachable!()
}

fn valid_terminal(term: &str) -> bool {
    !term.is_empty()
        && !term.chars().any(|c| c.is_whitespace() || c == '\0')
        && (!term.contains('/') || Path::new(term).is_absolute())
}

fn is_wezterm(prog: &str) -> bool {
    Path::new(prog).file_name().and_then(|s| s.to_str()) == Some("wezterm")
}

fn field<'a>(data: &'a Value, key: &str) -> Result<&'a str, String> {
    data.get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("{key} debe ser una cadena"))
}

fn mutation(kind: &str, data: &Value) -> Result<Value, String> {
    match kind {
        "fs.mkdir" => {
            let parent = directory(field(data, "parent")?)?;
            let name = field(data, "name")?;
            validate_entry_name(name)?;
            let target = parent.join(name);
            fs::create_dir(&target).map_err(|e| {
                if e.kind() == io::ErrorKind::AlreadyExists {
                    "Ya existe un elemento con ese nombre".into()
                } else {
                    e.to_string()
                }
            })?;
            Ok(event(
                "fs.mutated",
                json!({"action":"mkdir", "path":target, "parent":parent}),
            ))
        }
        "fs.rename" => {
            let (parent, src, _) = resolve_entry_path(field(data, "path")?)?;
            let name = field(data, "newName")?;
            validate_entry_name(name)?;
            let dst = parent.join(name);
            if src != dst {
                if fs::symlink_metadata(&dst).is_ok() {
                    return Err("Ya existe un elemento con ese nombre".into());
                }
                fs::rename(&src, &dst).map_err(|e| e.to_string())?;
            }
            Ok(event(
                "fs.mutated",
                json!({"action":"rename", "path":src, "targetPath":dst, "parent":parent}),
            ))
        }
        "fs.trash" => {
            let data_home = std::env::var_os("XDG_DATA_HOME")
                .map(PathBuf::from)
                .filter(|p| p.is_absolute())
                .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/share")))
                .ok_or("HOME no está definido")?;
            trash_with_data_dir(field(data, "path")?, &data_home)
        }
        "fs.copy" | "fs.move" => {
            let (parent, src, name) = resolve_entry_path(field(data, "source")?)?;
            let dest_dir = directory(field(data, "destDir")?)?;
            let meta = fs::symlink_metadata(&src).map_err(|e| e.to_string())?;
            if meta.is_dir()
                && dest_dir.starts_with(fs::canonicalize(&src).map_err(|e| e.to_string())?)
            {
                return Err("No se puede copiar una carpeta dentro de sí misma".into());
            }
            if kind == "fs.move" && parent == dest_dir {
                return Err("El elemento ya está en esa carpeta".into());
            }
            let mut dst = dest_dir.join(&name);
            if kind == "fs.move" && fs::symlink_metadata(&dst).is_ok() {
                return Err("Ya existe un elemento con ese nombre en la carpeta destino".into());
            }
            if kind == "fs.copy" {
                let split = if !meta.is_dir() {
                    name.rfind('.').filter(|i| *i > 0)
                } else {
                    None
                };
                let (stem, ext) = split.map(|i| name.split_at(i)).unwrap_or((&name, ""));
                let mut n = 1;
                while fs::symlink_metadata(&dst).is_ok() {
                    let suffix = if n == 1 {
                        "copia".to_owned()
                    } else {
                        format!("copia {n}")
                    };
                    dst = dest_dir.join(format!("{stem} ({suffix}){ext}"));
                    n += 1;
                }
                if let Err(e) = copy_entry_recursive(&src, &dst) {
                    let _ = remove_entry(&dst);
                    return Err(e.to_string());
                }
            } else {
                move_entry(&src, &dst).map_err(|e| e.to_string())?;
            }
            Ok(event(
                "fs.mutated",
                json!({"action":if kind == "fs.copy" {"copy"} else {"move"}, "path":src, "targetPath":dst, "parent":dest_dir}),
            ))
        }
        "fs.openTerminal" => {
            let dir = directory(field(data, "path")?)?;
            let mut programs = Vec::new();
            if let Ok(term) = std::env::var("TERMINAL") {
                if valid_terminal(&term) {
                    programs.push(term);
                }
            }
            programs.extend(
                [
                    "kitty",
                    "foot",
                    "alacritty",
                    "ghostty",
                    "wezterm",
                    "konsole",
                    "gnome-terminal",
                    "xterm",
                ]
                .iter()
                .map(|s| s.to_string()),
            );
            for prog in programs {
                let mut command = Command::new(&prog);
                if is_wezterm(&prog) {
                    command.arg("start").arg("--cwd").arg(&dir);
                }
                match command
                    .current_dir(&dir)
                    .stdin(Stdio::null())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .spawn()
                {
                    Ok(mut child) => {
                        std::thread::spawn(move || {
                            let _ = child.wait();
                        });
                        return Ok(event(
                            "fs.terminalOpened",
                            json!({"path":dir, "terminal":prog}),
                        ));
                    }
                    Err(e) if e.kind() == io::ErrorKind::NotFound => continue,
                    Err(e) => return Err(format!("No se pudo abrir terminal: {e}")),
                }
            }
            Err("No hay ningún terminal disponible".into())
        }
        _ => unreachable!(),
    }
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
            Some("fs.places") => Ok(event(
                "fs.places",
                places(command.get("data").unwrap_or(&Value::Null))?,
            )),
            Some(
                kind @ ("fs.mkdir" | "fs.rename" | "fs.trash" | "fs.copy" | "fs.move"
                | "fs.openTerminal"),
            ) => mutation(kind, command.get("data").unwrap_or(&Value::Null)),
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

    #[test]
    fn terminal_selection() {
        assert!(!valid_terminal("bin/terminal"));
        assert!(!valid_terminal("./terminal"));
        assert!(!valid_terminal("terminal --flag"));
        assert!(!valid_terminal("terminal\0"));
        assert!(valid_terminal("terminal"));
        assert!(valid_terminal("/usr/bin/wezterm"));
        assert!(is_wezterm("/usr/bin/wezterm"));
        assert!(is_wezterm("wezterm"));
        assert!(!is_wezterm("not-wezterm"));
    }

    #[test]
    fn trash_broken_symlink() {
        let temp = Temp::new();
        let src = temp.0.join("broken");
        let data = temp.0.join("data");
        std::os::unix::fs::symlink("missing", &src).unwrap();
        trash_with_data_dir(src.to_str().unwrap(), &data).unwrap();
        let dest = data.join("Trash/files/broken");
        assert!(fs::symlink_metadata(&src).is_err());
        assert_eq!(fs::read_link(dest).unwrap(), Path::new("missing"));
        assert!(data.join("Trash/info/broken.trashinfo").exists());
    }

    #[test]
    fn mutations_and_trash() {
        let temp = Temp::new();
        let root = &temp.0;
        let call = |kind, data| mutation(kind, &data);
        call("fs.mkdir", json!({"parent":root,"name":"one"})).unwrap();
        assert!(call("fs.mkdir", json!({"parent":root,"name":"one"})).is_err());
        for name in ["..", "a/b", " "] {
            assert!(call("fs.mkdir", json!({"parent":root,"name":name})).is_err());
        }
        fs::write(root.join("file.txt"), "original").unwrap();
        fs::write(root.join("other"), "other").unwrap();
        assert!(call(
            "fs.rename",
            json!({"path":root.join("file.txt"),"newName":"other"})
        )
        .is_err());
        assert_eq!(fs::read(root.join("other")).unwrap(), b"other");
        call(
            "fs.rename",
            json!({"path":root.join("file.txt"),"newName":"new.txt"}),
        )
        .unwrap();
        std::os::unix::fs::symlink(root.join("one"), root.join("link")).unwrap();
        call(
            "fs.rename",
            json!({"path":root.join("link"),"newName":"link2"}),
        )
        .unwrap();
        assert!(root.join("one").is_dir());
        let copy = call(
            "fs.copy",
            json!({"source":root.join("new.txt"),"destDir":root}),
        )
        .unwrap();
        assert!(copy["data"]["targetPath"]
            .as_str()
            .unwrap()
            .ends_with("new (copia).txt"));
        fs::write(root.join("one/inside"), "x").unwrap();
        std::os::unix::fs::symlink("inside", root.join("one/link")).unwrap();
        call("fs.copy", json!({"source":root.join("one"),"destDir":root})).unwrap();
        assert!(fs::symlink_metadata(root.join("one (copia)/link"))
            .unwrap()
            .file_type()
            .is_symlink());
        assert!(call(
            "fs.copy",
            json!({"source":root.join("one"),"destDir":root.join("one")})
        )
        .is_err());
        assert!(call(
            "fs.move",
            json!({"source":root.join("one"),"destDir":root.join("one")})
        )
        .is_err());
        assert!(call(
            "fs.move",
            json!({"source":root.join("new.txt"),"destDir":root})
        )
        .is_err());
        fs::write(root.join("one/new.txt"), "occupied").unwrap();
        assert!(call(
            "fs.move",
            json!({"source":root.join("new.txt"),"destDir":root.join("one")})
        )
        .is_err());
        call(
            "fs.move",
            json!({"source":root.join("other"),"destDir":root.join("one")}),
        )
        .unwrap();
        assert!(root.join("one/other").exists());
        let data = root.join("data");
        fs::create_dir(&data).unwrap();
        fs::write(root.join("space #"), "x").unwrap();
        trash_with_data_dir(root.join("space #").to_str().unwrap(), &data).unwrap();
        let info = fs::read_to_string(data.join("Trash/info/space #.trashinfo")).unwrap();
        assert!(info.contains("space%20%23\nDeletionDate="));
        assert_eq!(
            info.lines().last().unwrap().len(),
            "DeletionDate=2024-01-01T00:00:00".len()
        );
        fs::write(root.join("space #"), "y").unwrap();
        trash_with_data_dir(root.join("space #").to_str().unwrap(), &data).unwrap();
        assert!(data.join("Trash/info/space #.2.trashinfo").exists());
        assert!(trash_with_data_dir(data.join("Trash").to_str().unwrap(), &data).is_err());
        assert!(trash_with_data_dir(root.to_str().unwrap(), &data).is_err());
        trash_with_data_dir(root.join("link2").to_str().unwrap(), &data).unwrap();
        assert!(root.join("one").is_dir());
        assert!(fs::symlink_metadata(data.join("Trash/files/link2"))
            .unwrap()
            .file_type()
            .is_symlink());
        assert!(call("fs.openTerminal", json!({"path":root.join("missing")})).is_err());
        assert!(call("fs.openTerminal", json!({"path":root.join("new.txt")})).is_err());
    }

    #[test]
    fn sorting_and_validation() {
        let temp = Temp::new();
        fs::create_dir(temp.0.join("dir2")).unwrap();
        fs::create_dir(temp.0.join("dir10")).unwrap();
        fs::write(temp.0.join("a.z"), b"123").unwrap();
        fs::write(temp.0.join("b.a"), b"1").unwrap();
        let time = std::time::SystemTime::now();
        fs::File::open(temp.0.join("a.z"))
            .unwrap()
            .set_modified(time - std::time::Duration::from_secs(10))
            .unwrap();
        fs::File::open(temp.0.join("b.a"))
            .unwrap()
            .set_modified(time)
            .unwrap();
        for (sort, asc, desc) in [
            ("name", "a.z", "b.a"),
            ("size", "b.a", "a.z"),
            ("mtime", "a.z", "b.a"),
            ("type", "b.a", "a.z"),
        ] {
            for (reverse, first) in [(false, asc), (true, desc)] {
                let value = list(&json!({"path":temp.0,"sortBy":sort,"sortDesc":reverse})).unwrap();
                assert_eq!(value["sortBy"], sort);
                assert_eq!(value["sortDesc"], reverse);
                let entries = value["entries"].as_array().unwrap();
                assert!(
                    entries[0]["isDir"].as_bool().unwrap()
                        && entries[1]["isDir"].as_bool().unwrap()
                );
                assert_eq!(entries[2]["name"], first);
                assert!(entries.iter().all(|e| e["mtime"].as_u64().is_some()));
            }
        }
        for value in [json!("bad"), json!(3), json!(null)] {
            assert_eq!(
                list(&json!({"sortBy":value})).unwrap_err(),
                "sortBy debe ser name, size, mtime o type"
            );
        }
        for value in [json!("true"), json!(3), json!(null)] {
            assert_eq!(
                list(&json!({"sortDesc":value})).unwrap_err(),
                "sortDesc debe ser booleano"
            );
        }
    }

    #[test]
    fn hidden_extension_and_descending_directories() {
        let temp = Temp::new();
        for name in ["dir2", "dir10"] {
            fs::create_dir(temp.0.join(name)).unwrap();
        }
        for name in [".bashrc", "a", "z.aaa"] {
            fs::write(temp.0.join(name), b"x").unwrap();
        }
        let time = std::time::SystemTime::now();
        for (name, offset) in [("dir2", 10), ("dir10", 0)] {
            fs::File::open(temp.0.join(name))
                .unwrap()
                .set_modified(time - std::time::Duration::from_secs(offset))
                .unwrap();
        }
        let value = list(&json!({"path": temp.0, "showHidden": true, "sortBy": "type"})).unwrap();
        let names: Vec<_> = value["entries"]
            .as_array()
            .unwrap()
            .iter()
            .map(|entry| entry["name"].as_str().unwrap())
            .collect();
        assert_eq!(names, ["dir2", "dir10", ".bashrc", "a", "z.aaa"]);
        for (sort, expected) in [
            ("size", ["dir2", "dir10"]),
            ("type", ["dir2", "dir10"]),
            ("mtime", ["dir10", "dir2"]),
        ] {
            let value = list(
                &json!({"path": temp.0, "showHidden": true, "sortBy": sort, "sortDesc": true}),
            )
            .unwrap();
            let entries = value["entries"].as_array().unwrap();
            assert_eq!(entries[0]["name"], expected[0]);
            assert_eq!(entries[1]["name"], expected[1]);
            assert!(
                entries[0]["isDir"].as_bool().unwrap() && entries[1]["isDir"].as_bool().unwrap()
            );
        }
    }

    #[test]
    fn relative_configured_place_is_ignored() {
        let temp = Temp::new();
        let relative = format!(
            "explorer-relative-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        );
        let existing = Temp(std::env::current_dir().unwrap().join(&relative));
        fs::create_dir(&existing.0).unwrap();
        fs::write(
            temp.0.join("user-dirs.dirs"),
            format!("XDG_DOWNLOAD_DIR=\"{relative}\"\n"),
        )
        .unwrap();
        let value = places_with_env(Some(&temp.0), Some(&temp.0), None, None);
        assert!(!value["places"]
            .as_array()
            .unwrap()
            .iter()
            .any(|p| p["kind"] == "downloads"));
    }

    #[test]
    fn places_configuration_and_mounts() {
        let temp = Temp::new();
        let home = temp.0.join("home");
        let config = temp.0.join("config");
        let data = temp.0.join("data");
        let media = temp.0.join("media");
        for path in [
            home.join("quoted\"dir"),
            home.join("Documents"),
            config.clone(),
            data.join("Trash/files"),
            media.join("disk10"),
            media.join("disk2"),
        ] {
            fs::create_dir_all(path).unwrap();
        }
        fs::write(
            config.join("user-dirs.dirs"),
            "# comentario\nXDG_DESKTOP_DIR=\"$HOME\"\nXDG_DOWNLOAD_DIR=\"$HOME/quoted\\\"dir\"\n",
        )
        .unwrap();
        let value = places_with_env(Some(&home), Some(&config), Some(&data), Some(&media));
        let entries = value["places"].as_array().unwrap();
        let kinds: Vec<_> = entries
            .iter()
            .map(|p| p["kind"].as_str().unwrap())
            .collect();
        assert_eq!(
            kinds,
            [
                "home",
                "documents",
                "downloads",
                "trash",
                "root",
                "mount",
                "mount"
            ]
        );
        assert_eq!(
            entries[2]["path"],
            home.join("quoted\"dir").to_str().unwrap()
        );
        assert_eq!(entries[5]["name"], "disk2");
        assert_eq!(entries[6]["name"], "disk10");
        assert!(places(&json!([])).is_err());
        assert_eq!(
            handle(r#"{"version":2,"type":"fs.places"}"#, &mut 0)["type"],
            "fs.places"
        );
    }
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
