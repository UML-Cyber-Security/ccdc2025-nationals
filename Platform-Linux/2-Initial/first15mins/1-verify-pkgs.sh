# Check if the scrip is ran as root.
# $EUID is a env variable that contains the users UID
# -ne 0 is not equal zero
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

deb_packages=(
    "bash"
    "coreutils"
    "sudo"
    "passwd"
    "lib6c"
    "dpkg"
    "apt"
    "openssh-server"
    "net-tools"
    "dash"
    "libpam-modules"
    "util-linux"
    "pollkitd"
    "cron"
    "libpam-pwquality"
)

rhel_packages=(
    "bash"
    "coreutils"
    "sudo"
    "passwd"
    "glibc"
    "rpm"
    "dpkg"
    "yum"
    "openssh-server"
    "net-tools"
    "dash"
    "pam"
    "util-linux"
    "pollkit"
    "cronie"
    "pam_pwquality"
)

. /etc/os-release

echo "[!] Checking Various Packages, use \`dpkg --verify\` or \`rpm -Va\` to check all [!]"

if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "linuxmint" || "$ID" == "raspbian" ]]; then
    echo "Detected Debian-based system. Running Debian package verification..."
    for pkg in "${deb_packages[@]}"; do
        dpkg --verify $pkg # Provide no package to check all?
    done
elif [[ "$ID" == "rhel" || "$ID" == "centos" || "$ID" == "fedora" || "$ID" == "rocky" || "$ID" == "alma" ]]; then
    echo "Detected RHEL-based system. Running RHEL package verification..."
    for pkg in "${rhel_packages[@]}"; do
        rpm -V $pkg # use -Va to check all
    done
else
    echo "Unsupported system type detected."
fi