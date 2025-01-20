#!/bin/bash

#本脚本是用来安装LM-studio
clear
# 定义软件存放目录变量
aigc_dir="/Volumes/AIGC/"
software_dir="/Volumes/AIGC/software/"
target_dir="$HOME/.lmstudio/models/"

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

#函数启动LM Studio
start_lmstudio() {
	#!/bin/bash
	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 定义LM Studio app 路径
	LMStudio_PATH="/Applications/LM Studio.app"

	# 判断 Xcode 是否存在
	if [ ! -d "$LMStudio_PATH" ]; then
    	echo "LM Studio app 还未安装，请先安装 LM Studio app 。"
    	exit 1
	fi

	# 启动LM Studio app
	echo "启动LM Studio app..."
	open /Applications/LM\ Studio.app
}

#函数安装 LM Studio
install_lmstudio() {
	
	# 检查LM-studio应用是否已安装
	APP_NAME="LM Studio.app"
	APP_PATH="/Applications/$APP_NAME"
	DMG_PATH="/Volumes/AIGC/software/LM-Studio-arm64.dmg"
    
	if [ -d "$APP_PATH" ]; then
    	echo "$APP_NAME 已经安装在 $APP_PATH，可以启动执行。"
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
    	echo "$APP_NAME 未安装，现在开始安装。"
    	# 挂载 DMG 文件
    	MOUNT_POINT=$(hdiutil attach "$DMG_PATH" | grep Volumes | awk '{for (i=3; i<=NF; i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
    	if [ -z "$MOUNT_POINT" ]; then
        	echo "挂载 DMG 失败。请检查文件路径。"
        	exit 1
    	fi
    	echo "DMG 已挂载到 /Volumes/LMStudio。"
    	# 拷贝应用到 /Applications
    	cp -R "$MOUNT_POINT/$APP_NAME" /Applications/ && echo "$APP_NAME 安装成功。" || { echo "$APP_NAME 安装失败。"; exit 1; }
    	# 卸载 DMG
    	hdiutil detach "$MOUNT_POINT" || { echo "卸载 DMG 失败，挂载点可能不存在。"; exit 1; }
    	xattr -dr com.apple.quarantine /Applications/LM\ Studio.app
	

		# 定义一个函数来显示对话框并返回按钮标题
		display_dialog_with_button() {
  			osascript -e "tell application \"System Events\"
    		display dialog \"$1\" buttons {\"$2\"} default button \"$2\" with title \"$3\"
    		set buttonPressed to button returned of the result
    		return buttonPressed
  		end tell"
		}

		# 调用函数，传入对话框的文本、按钮标题和对话框标题
		button_pressed=$(display_dialog_with_button "请在应用程序中打开LM Studio，并启动 LM Studio，然后点击'继续'按钮继续: " "继续" "确认")

		# 根据用户的选择执行不同的操作
		if [ "$button_pressed" == "继续" ]; then
    		echo "用户已经确认初始化完成，继续复制模型 "
		else
    		echo "用户没有选择继续。退出"
    		exit 1
		fi

		# 检查目标目录是否存在，如果不存在则创建
		if [ ! -d "$target_dir" ]; then
    		echo "模型目标目录不存在，正在创建..."
    		mkdir -p "$target_dir"
		fi

		#复制模型文件
		echo "正在复制LMStudio模型文件..."
		cp -r "${aigc_dir}LMStudio_models/"* "$target_dir" || { echo "复制失败"; exit 1; }
		echo "复制完成，现在可以打开LM Studio开始使用"
	fi
}

# Main 
# 调用 lmstudio 安装函数
install_lmstudio

# 调用 lmstudio 启动函数
start_lmstudio

# 总体计时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo "所有任务完成，总耗时: ${TOTAL_TIME} 秒"

