#!/bin/bash 
base=socks5
kcptun_log_dir=/var/log/kcptun
shadowsocks_log_dir=/var/log/shadowsocks
if [ -d "/opt/node" ]; then
 rm -rf /opt/node/
fi
if [ -d "/opt/kcptun" ]; then
 rm -rf /opt/kcptun/
fi
if [ -f "/etc/supervisor/conf.d/kcptun-server.conf" ]; then
 rm -rf /etc/supervisor/conf.d/kcptun-server.conf
fi
if [ -f "/etc/supervisor/conf.d/shadowsocks-server.conf" ]; then
 rm -rf /etc/supervisor/conf.d/shadowsocks-server.conf
fi
if [ -d "${base}" ]; then
 rm -rf ${base}
fi
# 下载服务脚本
downlod_file() {
	cat >&2 <<-'EOF'

	开始下载kcptun shadowsocks...

	EOF
	if [ ! -f "socks5.tar.gz" ]; then
	     curl -o "socks5.tar.gz" "https://raw.githubusercontent.com/xiezhouyan/socks5/master/socks5.tar.gz"
	fi
     cat >&2 <<-'EOF'

	解压kcptun shadowsocks...

	EOF
	tar xzf socks5.tar.gz
}
# 安装需要的依赖软件
install_deps() {
	cat >&2 <<-'EOF'

	正在安装依赖软件...
	EOF

if ! command_exists supervisorctl; then
  apt-get update
  apt-get install supervisor -y
fi
}
# 安装服务
install_service() {
	cat >&2 <<-'EOF'

	正在配置系统服务...
	EOF
    cp ${base}/shadowsocks-server.conf /etc/supervisor/conf.d/
    cp ${base}/kcptun-server.conf /etc/supervisor/conf.d/
	restart_supervisor
}
# 安装kcptun shadowsocks
install_socks5(){
	cat >&2 <<-'EOF'

	正在安装SOCKS5...

	EOF
	cp -r ${base}/node /opt/node
	cp -r ${base}/kcptun /opt/kcptun
}
# 检查命令是否存在
command_exists() {
	command -v "$@" >/dev/null 2>&1
}
# 非正常退出
exit_with_error() {
  exit 1
}
# 重启 Supervisor
restart_supervisor() {
	if [ -d "$kcptun_log_dir" ]; then
			rm -f "$kcptun_log_dir"/*
	else
		mkdir -p "$kcptun_log_dir"
	fi

	if [ -d "$shadowsocks_log_dir" ]; then
		rm -f "$shadowsocks_log_dir"/*
	else
		mkdir -p "$shadowsocks_log_dir"
	fi
 systemctl restart supervisor
}
install_deps
downlod_file
install_socks5
install_service
echo "installed successfully"
exit 0
