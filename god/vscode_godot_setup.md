# Konfiguracja VS Code dla Godot 4.x (Poziom Senior)

Ten przewodnik opisuje profesjonalną integrację VS Code z Godot Engine za pomocą protokołu LSP (Language Server Protocol) oraz konfigurację zaawansowanego debugowania.

## 1. Wymagane Rozszerzenia (Extensions)
Zainstaluj poniższe rozszerzenia w VS Code:
- **godot-tools** (autor: ChrisKnyfe) – kluczowe dla LSP i autouzupełniania GDScript.
- **C#** oraz **C# Dev Kit** – (opcjonalnie) jeśli używasz Godot .NET.

## 2. Konfiguracja Globalna / Projektu (`.vscode/settings.json`)
Utwórz plik `.vscode/settings.json` w głównym katalogu projektu, aby odizolować ustawienia środowiska. Ustawienia te wymuszają rygorystyczne typowanie oraz poprawne mapowanie portów LSP.

```json
{
  "godotTools.editorPath.godot4": "SCIEZKA_DO_TWOJEGO_EXE_GODOT4",
  "godotTools.lsp.serverPort": 6005,
  "godotTools.lsp.serverAddress": "127.0.0.1",
  "editor.formatOnSave": true,
  "files.associations": {
    "*.tscn": "gdresource",
    "*.godot": "ini"
  },
  "editor.insertSpaces": false,
  "editor.tabSize": 4
}
```
*Uwaga: Zastąp `SCIEZKA_DO_TWOJEGO_EXE_GODOT4` faktyczną ścieżką do pliku wykonywalnego Godot na swoim dysku.*

## 3. Konfiguracja Debuggera (`.vscode/launch.json`)
Aby móc debugować grę bezpośrednio z poziomu VS Code (stawianie breakpointów, podgląd zmiennych, stos wywołań), utwórz plik `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Godot: Launch Game (Debug)",
      "type": "godot",
      "request": "launch",
      "project": "${workspaceFolder}",
      "address": "127.0.0.1",
      "port": 6006
    },
    {
      "name": "Godot: Attach to Editor",
      "type": "godot",
      "request": "attach",
      "address": "127.0.0.1",
      "port": 6005
    }
  ]
}
```

## 4. Konfiguracja w Godot Engine (Edytor Główny)
Aby Godot otwierał skrypty automatycznie w VS Code zamiast we wbudowanym edytorze:
1. Otwórz Godot Engine i przejdź do: **Editor -> Editor Settings** (Ustawienia Edytora).
2. W lewym panelu znajdź sekcję: **Text Editors -> External** (Edytory Zewnętrzne).
3. Zaznacz opcję: **Use External Editor** (Użyj zewnętrznego edytora) na `true`.
4. W polu **Exec Path** wskaż ścieżkę do pliku wykonywalnego VS Code (np. `code` lub pełna ścieżka do `code.exe`).
5. W polu **Exec Flags** wklej dokładnie: `{project} --goto {file}:{line}:{col}`

## 5. Senior Workflow z Claude Code
Mając tak skonfigurowane środowisko:
- Claude Code działający w terminalu VS Code ma bezpośredni wgląd w pliki projektu z poprawnym formatowaniem.
- Możesz poprosić Claude o refaktoryzację skryptu, a zmiany natychmiast pojawią się w VS Code i zostaną odświeżone w uruchomionym edytorze Godota.
- Możesz uruchamiać testy jednostkowe bezpośrednio z poziomu wbudowanego terminala VS Code za pomocą CLI Godota.
