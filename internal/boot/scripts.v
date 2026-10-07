module core

// Generic iPXE snippets shared by all providers. Each returns a complete
// #!ipxe script.

// wait_script is served while a machine is pending approval or while its
// assets are being prepared. It polls boot.ipxe again, so the machine proceeds
// automatically once the operator approves it.
pub fn wait_script(base_url string, mac string, message string) string {
	return '#!ipxe\n' + 'echo lab-v-ipxe: ${message}\n' + 'echo MAC: ${mac}\n' +
		'echo Open ${base_url}/ in a browser to approve this machine.\n' + 'sleep 10\n' +
		'chain ${base_url}/boot.ipxe?mac=${mac} || reboot\n'
}

// sanboot_script boots an already-installed machine from its local disk.
pub fn sanboot_script() string {
	return '#!ipxe\n' + 'echo lab-v-ipxe: system installed, booting from local disk...\n' +
		'sanboot --no-describe --drive 0x80 || exit 1\n'
}

// error_script shows a message and stops the boot.
pub fn error_script(message string) string {
	return '#!ipxe\necho lab-v-ipxe ERROR: ${message}\nsleep 30\nexit 1\n'
}
