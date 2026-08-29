import { DEFAULT_CONTROLS, type ControlSettings } from "@/store/gameStore";

export class InputState {
  keys = new Set<string>();
  touch: { x: number; y: number } | null = null;
  touchSprint = false;
  interactPressed = false;
  /** active when sprintMode === "toggle" */
  sprintToggled = false;
  settings: ControlSettings = { ...DEFAULT_CONTROLS };

  setSettings(s: ControlSettings) {
    // reset toggle when switching mode
    if (s.sprintMode !== this.settings.sprintMode) this.sprintToggled = false;
    this.settings = s;
  }

  private onKeyDown = (e: KeyboardEvent) => {
    const k = e.key.toLowerCase();
    if (["arrowup", "arrowdown", "arrowleft", "arrowright", " "].includes(k)) {
      e.preventDefault();
    }
    const wasDown = this.keys.has(k);
    this.keys.add(k);
    if (!wasDown && k === "shift" && this.settings.sprintMode === "toggle") {
      this.sprintToggled = !this.sprintToggled;
    }
    if (k === "e" || k === "enter" || k === " ") this.interactPressed = true;
  };
  private onKeyUp = (e: KeyboardEvent) => this.keys.delete(e.key.toLowerCase());

  attach() {
    window.addEventListener("keydown", this.onKeyDown, { passive: false });
    window.addEventListener("keyup", this.onKeyUp);
  }
  detach() {
    window.removeEventListener("keydown", this.onKeyDown);
    window.removeEventListener("keyup", this.onKeyUp);
  }

  getDirection(): { x: number; y: number } {
    let x = 0;
    let y = 0;
    if (this.keys.has("arrowleft") || this.keys.has("a")) x -= 1;
    if (this.keys.has("arrowright") || this.keys.has("d")) x += 1;
    if (this.keys.has("arrowup") || this.keys.has("w")) y -= 1;
    if (this.keys.has("arrowdown") || this.keys.has("s")) y += 1;
    if (this.touch) {
      x += this.touch.x;
      y += this.touch.y;
    }
    if (this.settings.invertY) y = -y;
    const len = Math.hypot(x, y);
    if (len < 0.1) return { x: 0, y: 0 };
    if (len > 1) { x /= len; y /= len; }
    return { x, y };
  }

  isSprinting() {
    if (this.settings.sprintMode === "toggle") {
      return this.sprintToggled || this.touchSprint;
    }
    return this.keys.has("shift") || this.touchSprint;
  }

  consumeInteract() {
    const v = this.interactPressed;
    this.interactPressed = false;
    return v;
  }
}
