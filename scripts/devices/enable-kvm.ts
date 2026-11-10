// Lets the runner's user use KVM, so the Android emulator runs accelerated. Linux; needs sudo.
// Usage: node scripts/devices/enable-kvm.ts
import { program, run, tempPath, writeFile } from "noda-scripts/ci";

program.description("Lets the runner's user use KVM (Linux, sudo).").parse();
// The udev rule from reactivecircus/android-emulator-runner's README.
const rule = tempPath("99-kvm4all.rules");
writeFile(rule, 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"\n');
run("sudo", ["cp", rule, "/etc/udev/rules.d/99-kvm4all.rules"]);
run("sudo", ["udevadm", "control", "--reload-rules"]);
run("sudo", ["udevadm", "trigger", "--name-match=kvm"]);
