#!/bin/bash
# This script can install or uninstall acer turbo fan service. It means, that your turbo fan button still will be available even after rebooting.
# To install service just run this script as the root (sudo) user.
# After installation you can manage it as a usual service manually. Example: 'systemctl start/stop turbo-fan',  'systemctl enable/disable turbo-fan'
# To uninstall service, run this script with 'remove' argument. Example: 'sudo bash ./install_service.sh remove'.
# Note!!! Before removing, don't forget to switch off the turbo button because you will have forever turbo fan :)
mode=${1:-install} # Allowed modes: "install" and "remove". Default: install.
service=turbo-fan # Service name
resume_service=turbo-fan-resume # Resume after sleep/suspend service name
target_dir=/opt/turbo-fan # Instalation folder
service_dir=/etc/systemd/system # Service setup folder (where all services are stored)
service_start_delay=5 # Delay in seconds before the service starts.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[Mode: $mode]";

# Sudo check
if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

# Check systemctl is installed
if [[ -z "$(whereis systemctl | sed 's/systemctl: //')"  ]]; then echo "systemctl is not installed"; exit 1; fi
# Check rsync is installed	
if [[ -z "$(whereis rsync | sed 's/rsync: //')"  ]]; then echo "rsync is not installed"; exit 1; fi

if [[ "$mode" == "install" || "$mode" == "remove" ]]; then
	# Check service is presented and remove if yes.
	if [[ -f "$service_dir/$service.service" ]] || [[ "$(systemctl --type=service | grep $service)" ]]; then
		echo "['$service' service is presented. Remove it.]";
		systemctl stop $service 2>/dev/null || true;
		systemctl disable $service 2>/dev/null || true;
		rm -f $service_dir/$service.service
	fi

	if [[ -f "$service_dir/$resume_service.service" ]]; then
		echo "['$resume_service' service is presented. Remove it.]";
		systemctl stop $resume_service 2>/dev/null || true;
		systemctl disable $resume_service 2>/dev/null || true;
		rm -f $service_dir/$resume_service.service
	fi

	systemctl daemon-reload

	if [[ "$mode" == "remove" ]]; then
		rm -f /etc/modprobe.d/facer-blacklist-acer-wmi.conf
	fi
		
	# Remove old files
	echo "[Remove old data]";
	rm -rvf $target_dir;
fi;

if [[ "$mode" == "install" ]]
then
	echo "[Create directories]";
	mkdir -p $target_dir

	echo "[Copy new data]";
	rsync -av "$REPO_DIR/"* $target_dir --exclude=".git/*"

	echo "[Blacklist conflicting acer_wmi module on boot]";
	echo "blacklist acer_wmi" > /etc/modprobe.d/facer-blacklist-acer-wmi.conf

	echo "[Create turbo-fan service]"
	cat << EOF > $service_dir/turbo-fan.service
[Unit]
Description=Enables Acer Predator turbo button and RGB keyboard (facer)
After=multi-user.target systemd-modules-load.service systemd-udevd.service
StartLimitIntervalSec=$service_start_delay

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
WorkingDirectory=$target_dir
ExecStart=/bin/bash $target_dir/service.sh
ExecStop=/bin/bash $target_dir/uninstall.sh

[Install]
WantedBy=multi-user.target
EOF

	echo "[Create turbo-fan-resume service]"
	cat << EOF > $service_dir/$resume_service.service
[Unit]
Description=Restore Acer Predator RGB keyboard theme after suspend/hibernate
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
User=root
WorkingDirectory=$target_dir
ExecStart=/bin/bash $target_dir/resume.sh

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

	chown -R root:root $target_dir

	KERNELVERSION=$(uname -r)

	cat << EOF > $target_dir/service.sh
#!/bin/bash
KERNELVERSION="$KERNELVERSION"
REPO_DIR="$REPO_DIR"
cd $target_dir

rm -f /dev/acer-gkbbl-0 /dev/acer-gkbbl-static-0

rebuild_module() {
	echo "[*] Rebuilding facer module for kernel \$(uname -r)..."
	make clean
	bash ./install.sh
	sed -i "s/^KERNELVERSION.*/KERNELVERSION=\"\$(uname -r)\"/" $target_dir/service.sh
}

if [ "\$(uname -r)" != "\$KERNELVERSION" ] || [ ! -f $target_dir/src/facer.ko ]; then
	rebuild_module
else
	rmmod acer_wmi 2>/dev/null || true
	rmmod facer 2>/dev/null || true
	modprobe wmi 2>/dev/null || true
	modprobe rfkill 2>/dev/null || true
	modprobe platform_profile 2>/dev/null || true
	modprobe sparse-keymap 2>/dev/null || true
	modprobe video 2>/dev/null || true
	if ! insmod $target_dir/src/facer.ko; then
		echo "[!] insmod failed (possible firmware/kernel ABI update). Triggering auto-rebuild..."
		rebuild_module
	fi
fi

# Wait up to 3 seconds for device nodes to appear
for _ in {1..15}; do
	if [[ -e /dev/acer-gkbbl-0 && -e /dev/acer-gkbbl-static-0 ]]; then
		break
	fi
	sleep 0.2
done

chmod 666 /dev/acer-gkbbl-0 /dev/acer-gkbbl-static-0 2>/dev/null || true

if [[ -x "\$REPO_DIR/my_theme.sh" ]]; then
	"\$REPO_DIR/my_theme.sh"
elif [[ -x "$target_dir/my_theme.sh" ]]; then
	"$target_dir/my_theme.sh"
fi
EOF

	cat << EOF > $target_dir/resume.sh
#!/bin/bash
REPO_DIR="$REPO_DIR"
sleep 1

if [[ ! -e /dev/acer-gkbbl-0 || ! -e /dev/acer-gkbbl-static-0 ]]; then
	/bin/bash $target_dir/service.sh
else
	chmod 666 /dev/acer-gkbbl-0 /dev/acer-gkbbl-static-0 2>/dev/null || true
	if [[ -x "\$REPO_DIR/my_theme.sh" ]]; then
		"\$REPO_DIR/my_theme.sh"
	elif [[ -x "$target_dir/my_theme.sh" ]]; then
		"$target_dir/my_theme.sh"
	fi
fi
EOF

	#locking down service file for security
	chown -R root:root $target_dir
	chmod 744 $target_dir/service.sh $target_dir/resume.sh

	systemctl daemon-reload
	systemctl enable $service
	systemctl enable $resume_service
	systemctl start $service
fi
