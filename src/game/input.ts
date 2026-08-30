import { DEFAULT_CONTROLS, type ControlSettings } from "@/store/gameStore";

export class InputState {
  keys = new Set<string>();
  touch: { x: number; y: number } | null = null;
  touchSprint = false;
  interactPressed = false;
  /** active when sprintMode === "toggle" */
  sprintToggled = false;
  gamepadIndex: number | null = null;
  gamepadDeadzone = 0.1;
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

  pollGamepad(): { x: number; y: number } | null {
    if (typeof navigator === "undefined" || !navigator.getGamepads) return null;
    const gamepads = navigator.getGamepads?.();
    if (!gamepads) return null;
    const gp = gamepads[this.gamepadIndex ?? 0];
    if (!gp) {
      this.gamepadIndex = null;
      return null;
    }
    this.gamepadIndex = gp.index;
    const lx = gp.axes[0] ?? 0;
    const ly = gp.axes[1] ?? 0;
    const len = Math.hypot(lx, ly);
    if (len < this.gamepadDeadzone) return null;
    const scale = 1 / len;
    return { x: lx * scale, y: ly * scale };
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
    const gamepadDir = this.pollGamepad();
    if (gamepadDir) {
      x += gamepadDir.x;
      y += gamepadDir.y;
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
    const gamepadSprint = this.checkGamepadButton(4) || this.checkGamepadButton(5); // LB/RB
    return this.keys.has("shift") || this.touchSprint || gamepadSprint;
  }

  consumeInteract() {
    const v = this.interactPressed;
    this.interactPressed = false;
    const gamepadInteract = this.checkGamepadButton(0); // A button
    return v || gamepadInteract;
  }

  private checkGamepadButton(button: number): boolean {
    if (typeof navigator === "undefined" || !navigator.getGamepads) return false;
    const gamepads = navigator.getGamepads?.();
    const gp = gamepads?.[this.gamepadIndex ?? 0];
    return gp?.buttons[button]?.pressed ?? false;
  }
}
