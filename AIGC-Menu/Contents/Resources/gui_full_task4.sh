#!/bin/bash

#本脚本是用来安装LangChain Chatchat
clear

# 定义软件存放目录变量
lab_dir="/Volumes/AIGC/lab/"
software_dir="/Volumes/AIGC/software/"

# 设置非交互式安装环境变量
export NONINTERACTIVE=1

# 开始计时
START_TIME=$(date +%s)


# 定义软件目录变量
software_dir="/Volumes/AIGC/software/"

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

# 函数：安装 Homebrew
install_homebrew() {
    echo "正在检查是否已经安装了Homebrew..."
    if [ -f ~/.zshrc ]; then
        source ~/.zshrc
    fi

    if command -v brew >/dev/null 2>&1; then
        echo "Homebrew已经安装，不需要安装."
    else
        echo "Homebrew需要安装，现在开始安装..."
        sudo mkdir -p /opt/homebrew/bin
        arch -arm64 sudo -S installer -verboseR -pkg "$software_dir"Homebrew-4.4.2.pkg -target /opt/homebrew/bin
    fi

    # 添加Homebrew到shell环境变量
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zshrc
    eval "$(/opt/homebrew/bin/brew shellenv)"
    source $HOME/.zshrc

    # 检查brew版本
    brew -v || { echo "HomeBrew安装失败"; exit 1; }
    echo "HomeBrew安装完成"
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

#            tar -xvzf "$software_dir"python_3.11_packages.tar.gz -C ~/miniconda3/pkgs || { echo "安装python 311 依赖包失败"; exit 1; }

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

# 函数：生成超级用户 
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

echo "1/9 安装基础环境..." 
# 生成超级用户
echo "检查用户权限..."
create_super_user_file

# 修改中国时区
echo "修改中国时区..."
sudo systemsetup -settimezone "Asia/Shanghai" 2>/dev/null 1>&2

# 开始安装 Xcode CLT/HomeBrew/Miniconda
echo "开始安装 Xcode CLT..."
install_xcode_clt

echo "开始安装 HomeBrew..."
install_homebrew

echo "开始安装 Miniconda..."
install_miniconda

echo "*******************************************"
echo "Xcode CLT/HomeBrew/Miniconda 基础软件安装完成。"
echo "*******************************************"


install_chatchat03() {
	#!/bin/bash

	# 定义环境目录变量
	ENV_DIR="$HOME/miniconda3/envs/chatchat03"

	# 使用if语句判断目录是否存在
	if [ -d "$ENV_DIR" ]; then
    	echo " chatchat03 已经安装，可以开始运行"
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

		# 安装chatchat03
		echo "正在安装chatchat03..."
		# 检查 ~/.zshrc 文件是否存在
		if [ -f ~/.zshrc ]; then
    		# 如果文件存在，执行 source 命令
    		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
		else
    		# 如果文件不存在，创建一个空的 .zshrc 文件
    		touch ~/.zshrc
    		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
		fi

		conda deactivate || { echo "退出当前conda环境失败"; exit 1; }
		echo "查询当前conda环境..."
		conda info --envs || { echo "显示当前conda环境列表失败"; exit 1; }
		echo "生成chatchat03环境..."

		#conda create -n chatchat03 python==3.11.10 -y || { echo "创建名为chatchat03的conda环境失败"; exit 1; }

		cd $HOME/miniconda3/envs || { echo "切换到miniconda3 env目录失败"; exit 1; }
		mkdir -p chatchat03 || { echo "创建envs下的Chatchat3目录失败"; exit 1; }
		#tar -xvzf /Volumes/AIGC/software/chatchat03.tar.gz -C ~/miniconda3/envs/chatchat03 || { echo "解包chatchat03数据包失败"; exit 1; }
		tar -xvzf /Volumes/AIGC/software/py311.tar.gz -C ~/miniconda3/envs/chatchat03 || { echo "解包chatchat03数据包失败"; exit 1; }
		echo "解包chatchat03成功"
		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
		$HOME/miniconda3/envs/chatchat03/bin/conda-unpack || { echo "移除mlx绑定失败"; exit 1; }
		echo "移除chatchat03绑定成功"
		conda activate chatchat03 || { echo "激活chatchat03环境失败"; exit 1; }

		# 离线克隆Langchain-Chatchat.git
		echo "离线克隆Langchain-Chatchat.git..."
		mkdir -p ~/Langchain-Chatchat || { echo "创建Langchain-Chatchat目录失败"; exit 1; }
		cp -r "${lab_dir}Langchain-Chatchat/"* ~/Langchain-Chatchat || { echo "复制Langchain-Chatchat文件失败"; exit 1; }

		# 离线安装Langchain-Chatchat.git依赖
		echo "离线安装Langchain-Chatchat依赖..."
		mkdir -p ~/langchain-requirements-file || { echo "创建langchain-requirements-file目录失败"; exit 1; }
		cp -r "${lab_dir}langchain-requirements-file/"* ~/langchain-requirements-file || { echo "复制langchain-requirements-file文件失败"; exit 1; }
		cd ~/langchain-requirements-file || { echo "进入langchain-requirements-file目录失败"; exit 1; }
		pip3 install --no-index --find-links=. Langchain-chatchat || { echo "安装Langchain-chatchat失败"; exit 1; }
		cd ~ || { echo "返回到家目录失败"; exit 1; }
		rm -rf ~/langchain-requirements-file || { echo "删除临时依赖文件目录失败"; exit 1; }

		# 离线安装httpx 0.27.2
		echo "离线安装httpx 0.27.2..."
		mkdir -p ~/httpx0-27-2 || { echo "创建httpx0-27-2目录失败"; exit 1; }
		cp -r "${lab_dir}httpx0-27-2/"* ~/httpx0-27-2 || { echo "复制httpx0-27-2文件失败"; exit 1; }
		cd ~/httpx0-27-2 || { echo "进入httpx0-27-2目录失败"; exit 1; }
		pip install --no-index --find-links=. httpx==0.27.2 --force-reinstall || { echo "安装httpx 0.27.2失败"; exit 1; }
		cd ~ || { echo "返回到家目录失败"; exit 1; }
		rm -rf ~/httpx0-27-2 || { echo "删除临时httpx目录失败"; exit 1; }

		# 离线安装duckduckgo_search
		echo "离线安装duckduckgo_search..."
		mkdir -p ~/duckduckgo_search || { echo "创建duckduckgo_search目录失败"; exit 1; }
		cp -r "${lab_dir}duckduckgo_search/"* ~/duckduckgo_search || { echo "复制duckduckgo_search文件失败"; exit 1; }
		cd ~/duckduckgo_search || { echo "进入httpx0-27-2目录失败"; exit 1; }
		pip install --no-index --find-links=. duckduckgo_search --force-reinstall || { echo "安装duckduckgo_search失败"; exit 1; }
		cd ~ || { echo "返回到家目录失败"; exit 1; }
		rm -rf ~/duckduckgo_search || { echo "删除临时duckduckgo_search目录失败"; exit 1; }

		# 循环检查Ollama是否安装，直到安装成功
		echo "循环检查Ollama是否安装，直到安装成功..."
		if [ ! -d "$HOME/Applications/Ollama.app" ]; then
    		unzip -o "${software_dir}Ollama-darwin.zip" -d ~/Applications/ || { echo "解压Ollama安装包失败"; exit 1; }
    		echo "Ollama安装成功，请到Application中打开Ollama并安装..."
		else
    		echo "Ollama.app 已经安装，继续安装."
		fi

		# 定义一个函数来显示对话框并返回按钮标题
		display_dialog_with_button() {
  			osascript -e "tell application \"System Events\"
    		display dialog \"$1\" buttons {\"$2\"} default button \"$2\" with title \"$3\"
    		set buttonPressed to button returned of the result
    		return buttonPressed
  		end tell"
		}

		# 调用函数，传入对话框的文本、按钮标题和对话框标题
		button_pressed=$(display_dialog_with_button "请在应用程序中打开Ollama，并完成 Ollama 初始化安装，然后点击'继续'按钮继续: " "继续" "确认")

		# 根据用户的选择执行不同的操作
		if [ "$button_pressed" == "继续" ]; then
    		echo "用户已经确认初始化完成，继续复制模型 "
		else
    		echo "用户没有选择继续。退出"
    		exit 1
		fi

		# 从本地U盘复制Ollama模型
		echo "开始从本地U盘复制Ollama模型..."

		# 定义模型路径
		USB_PATH="/Volumes/AIGC/OllamaModels"
		DEST_PATH="$HOME/.ollama"

		# 确保目标路径存在
		mkdir -p "$DEST_PATH" || { echo "确保目标路径存在失败"; exit 1; }

		# 检查U盘路径是否存在
		if [ -d "$USB_PATH" ]; then
    		cp -r "${USB_PATH}/"* "$DEST_PATH/" || { echo "从U盘复制模型失败"; exit 1; }
    		echo "模型已从U盘复制到 ～/.ollama 目录 。"
		else
    		echo "U盘路径不存在，请确认U盘已插入并挂载在 $USB_PATH。"
    		exit 1
		fi

		echo "模型推理框架已配置并加载模型。"
		echo "确认模型下载成功.."
		ollama_list_output=$(ollama list 2>&1)

		# 检查输出中是否包含特定的模型名称或错误信息
		if echo "$ollama_list_output" | grep -q "qwen2.5"; then
    		echo "模型已下载成功。列出下载成功的模型..."
    		ollama list
			elif echo "$ollama_list_output" | grep -q "Error"; then
    		echo "检测模型下载状态时出错：$ollama_list_output"
		else
    		echo "无法确定模型是否下载成功。"
		fi

		# 初次启动LangChain 
		echo "初次启动LangChain"
		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
		conda info --envs || { echo "显示conda环境列表失败"; exit 1; }

		# 指定conda环境的名称
		ENV_Chatchat="chatchat03"
		source ~/miniconda3/etc/profile.d/conda.sh || { echo "源conda配置失败"; exit 1; }
		conda activate chatchat03 || { echo "激活conda环境失败"; exit 1; }

		#设置 Chatchat 存储配置文件和数据文件的根目录
		echo "设置 Chatchat 存储配置文件和数据文件的根目录"
		export CHATCHAT_ROOT=$HOME/Langchain-Chatchat

		#chatchat执行初始化

		echo "复制nltk "
		mkdir -p ~/nltk_data || { echo "创建hnltk_data 目录失败"; exit 1; }
		cp -r /Volumes/AIGC/lab/nltk_data/* ~/nltk_data || { echo "复制hnltk_data文件失败"; exit 1; }

		echo "LangChain Chatchat 执行初始化" 
		chatchat init
		echo "chatchat初始化成功"

		#复制 model 设置文件
		echo "复制 model 设置文件"
		sudo cp /Volumes/AIGC/lab/model_settings.yaml ~/Langchain-Chatchat/model_settings.yaml || { echo "复制model设置文件失败"; exit 1; }
		username=$(whoami) || { echo "获取当前用户名失败"; exit 1; }
		sudo chown -R $username:staff ~/Langchain-Chatchat/model_settings.yaml || { echo "更改model设置文件所有权失败"; exit 1; }

		#初始化数据库
		echo "初始化数据库"
		chatchat kb -r 
		echo "数据库初始化完成"
	fi
}

start_chatchat03() {
	#!/bin/bash
	# 设置 Miniconda 路径
	# 重新加载 zshrc 文件
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 检查 conda 是否安装
	if ! command -v conda &> /dev/null; then
    	echo "Conda 未安装，请先安装 Conda 后再运行此脚本。"
    	exit 1
	else
    	echo "Conda 已安装，继续执行后续操作。"
	fi

	# 检查 conda 是否可用
	conda info --envs || { echo "获取conda环境列表失败"; exit 1; }

	# 指定conda环境的名称
	ENV_Chatchat="chatchat03"

	# 定义一个函数来检查特定的conda环境是否已经被激活
	check_and_activate_env() {
  	local env_name=$1
  	# 使用 conda info --envs 检查环境是否激活
  	if conda info --envs | grep -q "^/*.*$env_name"; then
    	echo "Conda environment '$env_name' is already active."
  	else
    	echo "请先安装LangChain再执行..."
    	exit 1
  	fi
	}

	# 检查并激活 MLX 环境
	check_and_activate_env "$ENV_Chatchat"

	# 源 conda 配置
	source ~/miniconda3/etc/profile.d/conda.sh || { echo "源conda配置失败"; exit 1; }
	# 激活 conda 环境
	conda activate chatchat03 || { echo "激活conda环境chatchat03失败"; exit 1; }

	# 进入 Langchain-Chatchat 目录
	cd ~/Langchain-Chatchat || { echo "进入Langchain-Chatchat目录失败"; exit 1; }

	# 启动 Langchain-Chatchat 并检查端口
	echo "启动Langchain-Chatchat..."
	nohup chatchat start -a > chatchat.log 2>&1 &

	# 检查 8501 端口是否被占用
	PORT=8501
	echo "等待Langchain-Chatchat服务启动并监听端口..."
	while ! nc -z 127.0.0.1 $PORT; do
    	sleep 1
    	echo "等待服务启动..."
	done

	echo "Langchain-Chatchat 服务已启动，正在打开 Safari..."

	# 打开 Safari 浏览器并访问 127.0.0.1:8501
	open -a Safari http://127.0.0.1:8501

	# 检查 Safari 是否成功打开页面
	echo "检查Safari是否成功打开页面..."
	curl -s http://127.0.0.1:8501 > /dev/null || { echo "Safari 打开页面失败，请手动检查服务状态和网络连接"; exit 1; }

}

# Main 
# 调用 chatchat03 安装函数
install_chatchat03

# 调用 chatchat03 启动函数
start_chatchat03

# 总体计时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo "所有任务完成，总耗时: ${TOTAL_TIME} 秒"
