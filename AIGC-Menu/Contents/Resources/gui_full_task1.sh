#!/bin/bash

#本脚本是用来安装Xcode 
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
		echo "完成超级用户权限检查。。。。"
    fi

}

# 函数：安装 Xcode Command Line Tools
install_xcode_clt() {
    echo "正在检查是否已经安装了xcode-select..."
    if ! xcode-select -p &>/dev/null; then
        echo "未找到 Xcode Command Line Tools，开始安装..."
        hdiutil attach "$software_dir"Command_Line_Tools_for_Xcode_16.dmg
        sudo -S installer -verboseR -pkg "/Volumes/Command Line Developer Tools/Command Line Tools.pkg" -target /
        hdiutil detach "/Volumes/Command Line Developer Tools"
        xcode-select -v || { echo "Xcode-select 安装失败"; exit 1; }
        echo "Xcode Command Line Tools 安装完成"
    else
        echo "Xcode Command Line Tools 已安装"
    fi
}

# 函数：安装 Xcode 
install_xcode() {

	# 定义 Xcode 路径
	XCODE_PATH="/Applications/Xcode.app"

	# 判断 Xcode 是否存在
	if [ ! -d "$XCODE_PATH" ]; then
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
		sudo spctl --master-disable

    	echo "开始安装 Xcode CLT..."
		install_xcode_clt
		echo "载入zsh配置文件..."
		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	
    	echo "Xcode 还未安装，开始安装 Xcode。"

		# 安装 macOS Xcode 
		echo "复制Xcode app..."
		rm -rf $HOME/Xcode
		mkdir -p $HOME/Xcode
		if [ ! -f "${software_dir}Xcode_16.xip" ]; then
    		echo "Xcode_16.xip 文件不存在, 请确保AIGC U盘上已经在software 目录下复制了Xcode安装文件"
    		exit 1
		fi
		cp "${software_dir}Xcode_16.xip" $HOME/Xcode || { echo "复制Xcode软件文件失败"; exit 1; }

		echo "解压缩Xcode app..."
		cd $HOME/Xcode || { echo "切换目录失败"; exit 1; }
		xip -x Xcode_16.xip || { echo "解压缩Xcode失败"; exit 1; }
		sudo mv Xcode.app /Applications/ || { echo "移动Xcode.app到/Applications/失败"; exit 1; }
		cd /Applications/ || { echo "切换到/Applications/目录失败"; exit 1; }
		echo "Xcode 解压缩成功。。。。"
		sudo xcode-select -s /Applications/Xcode.app/Contents/Developer || { echo "设置Xcode命令行工具路径失败"; exit 1; }

		# 检查 Xcode 是否安装
		if xcodebuild -version &> /dev/null; then
    		echo "Xcode 已安装完成，可以启动 。"
    		rm -rf $HOME/Xcode
		else
    		echo "Xcode未安装， 请检查"
		fi
	else
		echo "Xcode 已经安装，可以直接启动"
	fi
}

# 函数：启动 Xcode 
start_xcode() {

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 定义 Xcode 路径
	XCODE_PATH="/Applications/Xcode.app"

	# 判断 Xcode 是否存在
	if [ ! -d "$XCODE_PATH" ]; then
    	echo "Xcode 还未安装，请先安装 Xcode。"
    	exit 1
	fi

	# 启动Xcode app
	echo "启动Xcode app..."
	open $XCODE_PATH || { echo "启动Xcode app 失败"; exit 1; }
	echo "启动Xcode app 成功了, 现在可以使用Xcode app了..."
}

# Main 
# 调用Xcode 安装函数
install_xcode

# 调用Xcode 启动函数
start_xcode

# 总体计时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo "所有任务完成，总耗时: ${TOTAL_TIME} 秒"