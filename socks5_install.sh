#!/bin/bash 
base=socks5
pass=`openssl rand 6 -base64`
kcptun_log_dir=/var/log/kcptun
shadowsocks_log_dir=/var/log/shadowsocks
if [ -d "/opt/node" ]; then
 rm -rf /opt/node/
fi
if [ -d "/opt/kcptun" ]; then
 rm -rf /opt/kcptun/
fi
if [ -f "/etc/supervisor/conf.d/kcptun.conf" ]; then
 rm -rf /etc/supervisor/conf.d/kcptun.conf
fi
if [ -f "/etc/supervisor/conf.d/shadowsocks.conf" ]; then
 rm -rf /etc/supervisor/conf.d/shadowsocks.conf
fi
if [ -d "${base}" ]; then
 rm -rf ${base}
fi
# 下载服务脚本
downlod_file() {
	cat >&2 <<-'EOF'

	开始下载kcptun shadowsocks...

	EOF

     curl -o "socks5.tar.gz" "https://raw.githubusercontent.com/xiezhouyan/socks5/master/socks5.tar.gz"

     cat >&2 <<-'EOF'

	解压kcptun shadowsocks...

	EOF
	tar xzf socks5.tar.gz

	cp -rf ${base}/supervisord /etc/init.d/

	if ! chmod a+x /etc/init.d/supervisord; then
		cat >&2 <<-'EOF'

		设置执行权限失败...
		EOF
		exit_with_error
	fi
}
# 安装需要的依赖软件
install_deps() {
	cat >&2 <<-'EOF'

	正在安装依赖软件...
	EOF

#	yum makecache
#	yum update -y ca-certificates
	yum install -y curl wget python-setuptools tar zip unzip

	if ! easy_install supervisor; then
		cat >&2 <<-'EOF'

		安装 Supervisor 失败!
		EOF
		exit_with_error
	fi

	[ -d /etc/supervisor/conf.d ] || mkdir -p /etc/supervisor/conf.d

	if [ ! -s /etc/supervisor/supervisord.conf ]; then

		if ! command_exists echo_supervisord_conf; then
			cat >&2 <<-'EOF'

			未找到 echo_supervisord_conf, 无法自动创建 Supervisor 配置文件!
			可能是当前安装的 supervisor 版本过低
			EOF
			exit_with_error
		else
			if ! echo_supervisord_conf > /etc/supervisor/supervisord.conf; then
				cat >&2 <<-'EOF'

				创建 Supervisor 配置文件失败!
				EOF
				exit_with_error
			fi
		fi
	fi
}
# 安装服务
install_service() {
	cat >&2 <<-'EOF'

	正在配置系统服务...
	EOF

    chkconfig --add supervisord
    chkconfig supervisord on
    cp ${base}/shadowsocks.conf /etc/supervisor/conf.d/
    cp ${base}/kcptun.conf /etc/supervisor/conf.d/
	$(grep -q "^files\s*=\s*\/etc\/supervisor\/conf\.d\/\*\.conf$" /etc/supervisor/supervisord.conf) || {
			if grep -q "^\[include\]$" /etc/supervisor/supervisord.conf; then
				sed -i '/^\[include\]$/a files = \/etc\/supervisor\/conf.d\/\*\.conf' /etc/supervisor/supervisord.conf
			else
				sed -i '$a [include]\nfiles = /etc/supervisor/conf.d/*.conf' /etc/supervisor/supervisord.conf
			fi
	}
	restart_supervisor
}
# 安装kcptun shadowsocks
install_socks5(){
	cat >&2 <<-'EOF'

	正在安装SOCKS5...

	EOF
	cp -r ${base}/node /opt/node
	cp -r ${base}/kcptun /opt/kcptun
	sed -i "s/shadowsocks_password/${pass}/g" ${base}/config.json
	sed -i "s/kcptun_password/${pass}/g" ${base}/server-config.json
	cp -rf ${base}/config.json /opt/node/lib/node_modules/shadowsocks/
	cp -rf ${base}/server-config.json /opt/kcptun/
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
	if [ -x /etc/init.d/supervisord ]; then

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


		if ! service supervisord restart; then
			cat >&2 <<-'EOF'

			重启 Supervisor 失败, Kcptun 无法正常启动!
			EOF

			exit_with_error
		fi
	else
		cat >&2 <<-'EOF'

		未找到 Supervisor 服务, 请手动检查!
		EOF

		exit_with_error
	fi


}
install_deps
downlod_file
install_socks5
install_service
echo "installed successfully password is ${pass}"
exit 0
