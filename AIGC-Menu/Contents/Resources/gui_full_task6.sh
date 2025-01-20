#!/bin/bash

#本脚本是用来安装Asitop
clear

# 定义软件存放目录变量
lab_dir="/Volumes/AIGC/lab/"
software_dir="/Volumes/AIGC/software/"

# 开始计时
START_TIME=$(date +%s)

# 载入zsh配置文件，确保conda命令可用
echo "载入zsh配置文件..."
# 检查 ~/.zshrc 文件是否存在
if [ -f ~/.zshrc ]; then
    # 如果文件存在，执行 source 命令
    source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
else
    # 如果文件不存在，创建一个空的 .zshrc 文件
    touch ~/.zshrc
#    echo "~/.zshrc 文件不存在，已创建一个空文件。"
    source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
fi

# 安装 macOS 资源监测软件 asitop 
echo "正在安装 macOS 资源监测软件：asitop ..."

create_super_user_file() {
	# 获取当前用户名
	username=$(whoami) || { echo "获取当前用户名失败"; exit 1; }

	# 定义文件的保存路径
	save_path="$HOME/Downloads"

	# 确保下载目录存在
	mkdir -p "$save_path" || { echo "创建下载目录失败"; exit 1; }

	# 检查目录权限并设置为755，如果需要的话
	if [ ! -w "$save_path" ]; then
    	echo "Directory $save_path is not writable. Changing permissions."
    	sudo chmod 755 "$save_path" || { echo "更改目录权限失败"; exit 1; }
	fi

	# 创建一个文件，文件名是whoami的结果，文件内容是特定的字符串
	# 检查文件是否已经存在，如果存在则先删除
	if [ -e "$save_path/$username" ]; then
    	echo "File $save_path/$username already exists. Removing it."
    	sudo rm "$save_path/$username" || { echo "删除已存在文件失败"; exit 1; }
	fi

    if [ -e /etc/sudoers.d"/$username" ]; then
    	echo "超级用户已经存在，继续安装" 
    else
       # 使用 osascript 弹出对话框请求管理员密码
		password=$(osascript -e 'Tell application "System Events"
    	display dialog "请输入管理员密码:" default answer "" with hidden answer with title "管理员验证"
    	text returned of result
		end tell')

		# 使用获取到的密码执行 sudo 命令
		echo "$password" | sudo -S command
			
		# 使用tee命令创建并写入文件，tee命令可以处理权限问题
		echo "${username} ALL=(ALL) NOPASSWD: ALL" | sudo tee "$save_path/$username" > /dev/null || { echo "创建并写入文件失败"; exit 1; }

		# 复制文件
		sudo mv "$save_path/$username" /etc/sudoers.d || { echo "复制文件到 /etc/sudoers.d 失败"; exit 1; }

		# 输出文件路径
		echo "Super User file created at: $save_path/$username and moved to /etc/sudoers.d"

    fi

}

# 函数：安装 Miniconda
install_miniconda() {
    if command -v conda >/dev/null 2>&1; then
        echo "Miniconda 已经安装过了."
    else
        echo "开始安装Miniconda..."
        if [ -f "$software_dir"Miniconda3-latest-MacOSX-arm64.sh ]; then
            bash "$software_dir"Miniconda3-latest-MacOSX-arm64.sh -b -u -p ~/miniconda3 || { echo "安装失败"; exit 1; }
            cd ~ || exit
#           tar -xvzf "$software_dir"python_3.11_packages.tar.gz -C ~/miniconda3/pkgs || { echo "安装python 311 依赖包失败"; exit 1; }
            cp -r /Volumes/AIGC/lab/conda-pkgs/* ~/miniconda3/pkgs || { echo "复制python 311 依赖包失败"; exit 1; }
            echo "安装python 3.11 依赖包成功"
            source ~/miniconda3/bin/activate || { echo "重新激活 miniconda 失败"; exit 1; }
            ~/miniconda3/bin/conda init --all || { echo "conda init zsh 失败"; exit 1; }
            source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
            echo "Miniconda 安装成功"
        else
            echo "Miniconda 安装包没有发现，请下载."
            exit 1
        fi
    fi
}

# 定义一个函数来检查特定的conda环境是否已经被激活
check_and_activate_env() {
  	local env_name=$1
  	# 使用 conda info --envs 检查环境是否激活
  	if conda info --envs | grep -q "^/*.*$env_name"; then
    	echo "Conda environment '$env_name' is already active."
  	else
    	echo "现在Miniconda中安装asitop..."
    	# 创建名为asitop的新conda环境，并指定Python版本为3.12
		#conda create -n asitop python=3.12 -y || { echo "创建conda环境失败"; exit 1; }
		cd $HOME/miniconda3/envs || { echo "切换到miniconda3 env目录失败"; exit 1; }
		mkdir -p asitop || { echo "创建envs下的asitop目录失败"; exit 1; }
		tar -xvzf /Volumes/AIGC/software/py312.tar.gz -C ~/miniconda3/envs/asitop || { echo "解包asitop数据包失败"; exit 1; }
		echo "解包asitop成功"
		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
		$HOME/miniconda3/envs/asitop/bin/conda-unpack || { echo "移除asitop绑定失败"; exit 1; }
		echo "移除asitop绑定成功"
  	fi
}


# 函数：安装 Install asitop
install_asitop() {

	# 定义环境目录变量
	ENV_DIR="$HOME/miniconda3/envs/asitop"

	# 使用if语句判断目录是否存在
	if [ -d "$ENV_DIR" ]; then
    	echo "asitop 已经安装，可以开始运行"
    else
		#开始为“AIGC”的优盘是检测
		# 函数：显示对话框
		display_dialog_with_button() {
  			osascript -e "tell application \"System Events\"
    		display dialog \"$1\" buttons {\"$2\"} default button \"$2\" with title \"$3\"
    		set buttonPressed to button returned of the result
    		return buttonPressed
  		end tell"
		}

		# 检查卷标为“AIGC”的优盘是否已插入
		diskutil list | grep -q "AIGC"

		# 检查grep命令的退出状态
		if [ $? -ne 0 ]; then
  			# 如果没有找到“AIGC”，则显示对话框提示用户插入优盘
  			button_pressed=$(display_dialog_with_button "请插入卷标为'AIGC'的优盘。" "确定" "优盘未检测到")
  			# 由于只有一个按钮，所以这里不需要检查button_pressed的值
  			exit 1
		else
  			echo "卷标为'AIGC'的优盘已检测到，继续执行后续操作..."
  			# 在这里添加后续操作的脚本
		fi

		# 生成超级用户
		echo "检查用户权限..."
		create_super_user_file

		# 退出当前激活的conda环境
		echo "开始安装 Miniconda..."
		install_miniconda
		conda deactivate || { echo "退出当前conda环境失败"; exit 1; }

		# 检查并激活 MLX 环境
		# 指定asitop环境的名称
		ENV_MLX="asitop"
		check_and_activate_env "$ENV_MLX"

		# 激活asitop环境
		conda activate asitop || { echo "激活conda环境失败"; exit 1; }

		# 检测asitop是否已经安装
		if pip list | awk '{print $1}' | grep asitop; then
    		echo "asitop已安装，跳过安装步骤。"
		else	
			# 在用户目录下创建asitop文件夹
			mkdir -p ~/asitop || { echo "创建asitop目录失败"; exit 1; }
			# 复制软件文件到用户目录下的asitop文件夹
			echo "复制asitop软件文件..."
			cp -r "${lab_dir}asitop/"* ~/asitop/ || { echo "复制asitop软件文件失败"; exit 1; }

			# 进入asitop目录
			cd ~/asitop || { echo "进入asitop目录失败"; exit 1; }
    		echo "使用pip安装asitop..."
    		pip install --no-index --find-links=. asitop || { echo "pip安装asitop失败"; exit 1; }
    		# 返回到用户目录
			cd ~ || { echo "返回到用户目录失败"; exit 1; }

			# 删除asitop文件夹，清理临时文件
			echo "清理临时文件..."
			rm -rf ~/asitop || { echo "清理临时文件失败"; exit 1; }
		fi
	fi
}

# 函数：安装 Start asitop
start_asitop() {

	#!/bin/bash
	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 安装 macOS 资源监测软件 asitop 
	echo "正在启动 macOS 资源监测软件：asitop ..."
	
	# 检查 conda 是否安装
	if ! command -v conda &> /dev/null; then
    	echo "Conda 未安装，请先安装 Conda 后再运行此脚本。"
    	exit 1
	else
    	echo "Conda 已安装，继续执行后续操作。"
	fi

	# 指定asitop环境的conda环境是否已经被激活
	env_name="asitop"
  	# 使用 conda info --envs 检查环境是否激活
  	if conda info --envs | grep -q "^/*.*$env_name"; then
    	echo "Conda environment '$env_name' is already active."
  	else
    	echo "请先在Miniconda中安装asitop 再执行..."
    	exit 1
  	fi

	# 检查并激活 MLX 环境
#	ENV_MLX="asitop"
#	check_and_activate_env "$ENV_MLX"

	# 退出当前激活的conda环境
	conda deactivate || { echo "退出当前conda环境失败"; exit 1; }

	# 激活asitop环境
	conda activate asitop || { echo "激活asitop 环境失败"; exit 1; }

	# 启动asitop
	sudo asitop || { echo "启动asitop失败"; exit 1; }
}

# Main 
# 调用asitop 安装函数
install_asitop

# 调用asitop 启动函数
start_asitop


# 总体计时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo "所有任务完成，总耗时: ${TOTAL_TIME} 秒"