#!/bin/bash

#本脚本是用来安装Apple mlx
clear

# 定义软件目录变量
lab_dir="/Volumes/AIGC/lab/"
aigc_dir="/Volumes/AIGC/"
software_dir="/Volumes/AIGC/software/"
echo "定义软件目录变量..."

export NONpip3INTERACTIVE=1
echo "设置非交互式安装环境变量..."

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

# 开始计时
START_TIME=$(date +%s)

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
        echo "Homebrew未安装，现在开始安装..."
        arch -arm64 sudo -S installer -verboseR -pkg "$software_dir"Homebrew-4.4.2.pkg -target /
        echo "Homebrew安装完毕，现在开始配置..."
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

#函数安装MLX
install_mlx() {
	#!/bin/bash

	# 定义环境目录变量
	ENV_DIR="$HOME/miniconda3/envs/mlx"

	# 使用if语句判断目录是否存在
	if [ -d "$ENV_DIR" ]; then
    	echo "MLX 已经安装，可以开始运行"
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
	
		echo "安装基础环境..." 
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

		# 安装 Apple MLX framework
		echo "正在安装 Apple MLX framework..."
		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
		conda deactivate || { echo "退出conda环境失败"; exit 1; }
		#conda create -n mlx python=3.12 -y || { echo "创建conda环境mlx失败"; exit 1; }

		#Create MLX by Local file 
		cd $HOME/miniconda3/envs || { echo "切换到miniconda3 envs目录失败"; exit 1; }
		mkdir -p mlx || { echo "创建envs下的Chatchat3目录失败"; exit 1; }
		tar -xvzf /Volumes/AIGC/software/py312.tar.gz -C ~/miniconda3/envs/mlx || { echo "解包mlx数据包失败"; exit 1; }
		echo "解包mlx成功"
		source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; } 
		$HOME/miniconda3/envs/mlx/bin/conda-unpack || { echo "移除mlx绑定失败"; exit 1; }
		echo "移除mlx绑定成功"

		conda activate mlx || { echo "激活conda环境mlx失败"; exit 1; }

		# 克隆 MLX Examples 并安装依赖
		echo "正在安装 mlx 和 mlx-lm..."
		mkdir -p ~/mlx || { echo "创建mlx目录失败"; exit 1; }
		cp -r "${lab_dir}mlx/"* ~/mlx/ || { echo "复制mlx文件失败"; exit 1; }
		cd ~/mlx/ || { echo "进入mlx目录失败"; exit 1; }
		pip3 install --no-index --find-links=. mlx || { echo "安装mlx失败"; exit 1; }
		rm -rf ~/mlx/ || { echo "清理mlx目录失败"; exit 1; }

		mkdir -p ~/mlx-lm || { echo "创建mlx-lm目录失败"; exit 1; }
		cp -r "${lab_dir}mlx-lm/"* ~/mlx-lm/ || { echo "复制mlx-lm文件失败"; exit 1; }
		cd ~/mlx-lm || { echo "进入mlx-lm目录失败"; exit 1; }
		pip3 install --no-index --find-links=. mlx-lm || { echo "安装mlx-lm失败"; exit 1; }
		rm -rf ~/mlx-lm || { echo "清理mlx-lm目录失败"; exit 1; }

		# 安装 mlx-examples 及其依赖
		echo "正在安装 mlx-examples 及其依赖..."
		mkdir -p ~/mlx-examples || { echo "创建mlx-examples目录失败"; exit 1; }
		cp -r "${lab_dir}mlx-examples/"* ~/mlx-examples/ || { echo "复制mlx-examples文件失败"; exit 1; }

		# 安装 LLaMA 依赖
		echo "正在安装 LLaMA 依赖..."
		mkdir -p ~/llms-llama-req || { echo "创建llms-llama-req目录失败"; exit 1; }
		cp -r "${lab_dir}llms-llama-req/"* ~/llms-llama-req/ || { echo "复制llms-llama-req文件失败"; exit 1; }
		cd ~/llms-llama-req || { echo "进入llms-llama-req目录失败"; exit 1; }
		pip3 install *.whl || { echo "安装LLaMA依赖失败"; exit 1; }
		rm -rf ~/llms-llama-req || { echo "清理llms-llama-req目录失败"; exit 1; }

		# 安装 MLX-LM 依赖
		echo "正在安装 MLX-LM 依赖..."
		mkdir -p ~/llms-mlx_lm-req || { echo "创建llms-mlx_lm-req目录失败"; exit 1; }
		cp -r "${lab_dir}llms-mlx_lm-req/"* ~/llms-mlx_lm-req/ || { echo "复制llms-mlx_lm-req文件失败"; exit 1; }
		cd ~/llms-mlx_lm-req || { echo "进入llms-mlx_lm-req目录失败"; exit 1; }
		pip3 install *.whl || { echo "安装MLX-LM依赖失败"; exit 1; }
		rm -rf ~/llms-mlx_lm-req || { echo "清理llms-mlx_lm-req目录失败"; exit 1; }

		# 安装 Stable Diffusion 依赖
		echo "正在安装 Stable Diffusion 依赖..."
		mkdir -p ~/stable_diffusion-req || { echo "创建stable_diffusion-req目录失败"; exit 1; }
		cp -r "${lab_dir}stable_diffusion-req/"* ~/stable_diffusion-req/ || { echo "复制stable_diffusion-req文件失败"; exit 1; }
		cd ~/stable_diffusion-req || { echo "进入stable_diffusion-req目录失败"; exit 1; }
		pip3 install *.whl || { echo "安装Stable Diffusion依赖失败"; exit 1; }
		rm -rf ~/stable_diffusion-req || { echo "清理stable_diffusion-req目录失败"; exit 1; }

		# 安装 Flux 依赖
		echo "正在安装 Flux 依赖..."
		mkdir -p ~/flux-req || { echo "创建flux-req目录失败"; exit 1; }
		cp -r "${lab_dir}flux-req/"* ~/flux-req/ || { echo "复制flux-req文件失败"; exit 1; }
		cd ~/flux-req || { echo "进入flux-req目录失败"; exit 1; }
		pip3 install *.whl || { echo "安装Flux依赖失败"; exit 1; }
		rm -rf ~/flux-req || { echo "清理flux-req目录失败"; exit 1; }

		# 安装 LLaVA 依赖
		echo "正在安装 LLaVA 依赖..."
		mkdir -p ~/llava-req || { echo "创建llava-req目录失败"; exit 1; }
		cp -r "${lab_dir}llava-req/"* ~/llava-req/ || { echo "复制llava-req文件失败"; exit 1; }
		cd ~/llava-req || { echo "进入llava-req目录失败"; exit 1; }
		pip3 install *.whl || { echo "安装LLaVA依赖失败"; exit 1; }
		rm -rf ~/llava-req || { echo "清理llava-req目录失败"; exit 1; }

		# 安装 Jupyter Lab
		echo "安装 Jupyter Lab..."
		mkdir -p ~/jupyterlab || { echo "创建jupyterlab目录失败"; exit 1; }
		cp -r "${lab_dir}jupyterlab/"* ~/jupyterlab/ || { echo "复制jupyterlab文件失败"; exit 1; }
		cd ~/jupyterlab || { echo "进入jupyterlab目录失败"; exit 1; }
		pip3 install *.whl || { echo "安装Jupyter Lab失败"; exit 1; }
		rm -rf ~/jupyterlab || { echo "清理jupyterlab目录失败"; exit 1; }

		# 安装 asitop
		echo "安装 asitop..."
		mkdir -p ~/asitop || { echo "创建asitop目录失败"; exit 1; }
		cp -r "${lab_dir}asitop/"* ~/asitop/ || { echo "复制asitop软件文件失败"; exit 1; }
		cd ~/asitop || { echo "进入asitop目录失败"; exit 1; }
		pip3 install --no-index --find-links=. asitop || { echo "安装asitop失败"; exit 1; }
		rm -rf ~/asitop || { echo "清理临时文件失败"; exit 1; }

		# 安装 torch
		echo "安装 torch..."
		mkdir -p ~/torch || { echo "创建torch目录失败"; exit 1; }
		cp -r "${lab_dir}torch/"* ~/torch/ || { echo "复制torch文件失败"; exit 1; }
		cd ~/torch || { echo "进入torch目录失败"; exit 1; }
		pip3 install *.whl || { echo "安装torch失败"; exit 1; }
		rm -rf ~/torch || { echo "清理torch目录失败"; exit 1; }

		# 编译 llama.cpp
		echo "编译 llama.cpp..."
		mkdir -p ~/llama.cpp || { echo "创建llama.cpp目录失败"; exit 1; }
		cp -r "${lab_dir}llama.cpp/"* ~/llama.cpp/ || { echo "复制llama.cpp文件失败"; exit 1; }
		if command -v xcodebuild >/dev/null 2>&1; then sudo xcodebuild -license accept; fi
		cd ~/llama.cpp || { echo "进入llama.cpp目录失败"; exit 1; }
		make || { echo "编译llama.cpp失败"; exit 1; }

		# 复制模型
		echo "复制模型..."
		mkdir -p ~/mlx-models || { echo "创建mlx-models目录失败"; exit 1; }
		cp -r "${aigc_dir}mlx-models/"* ~/mlx-models/ || { echo "复制mlx-models文件失败"; exit 1; }
		
		echo "复制LAB..."
		mkdir -p ~/Lab-Finetuning || { echo "创建Lab-Finetuning目录失败"; exit 1; }
		cp -r "${aigc_dir}Lab-Finetuning/"* ~/Lab-Finetuning/ || { echo "复制Lab-Finetuning文件失败"; exit 1; }
	fi

}

#函数启动MLX
start_mlx() {
	#!/bin/bash
	source ~/.zshrc 

	# 检查 conda 是否安装
	if ! command -v conda &> /dev/null; then
    	echo "Conda 未安装，请先安装 Conda 后再运行此脚本。"
    	exit 1
	else
    	echo "Conda 已安装，继续执行后续操作。"
	fi

	# 设置 Miniconda 路径
	conda info --envs || { echo "获取conda环境列表失败"; exit 1; }

	# 指定conda环境的名称
	ENV_MLX="mlx"

	# 定义一个函数来检查特定的conda环境是否已经被激活
	check_and_activate_env() {
  		local env_name=$1
  		# 使用 conda info --envs 检查环境是否激活
  		if conda info --envs | grep -q "^/*.*$env_name"; then
    		echo "Conda environment '$env_name' is already active."
  		else
    		echo "请先安装MLX 再执行..."
    		exit 1
  		fi
	}

	# 检查并激活 MLX 环境
	check_and_activate_env "$ENV_MLX"

	# 启动 mlx 并在后台运行
	#echo "Starting MLX..."
	source ~/miniconda3/etc/profile.d/conda.sh || { echo "源conda配置失败"; exit 1; }
	cd $HOME/ || { echo "进入家目录失败"; exit 1; }
	conda deactivate || { echo "退出conda环境失败"; exit 1; }
	conda activate mlx || { echo "激活conda环境 mlx 失败"; exit 1; }

	##测试mlx_lm chat
	echo "mlx_lm chat test"
	#mlx_lm.chat --model ~/mlx-models/Qwen2.5-7B-Instruct 
	jupyter lab "Lab-Finetuning/Finetuning.ipynb" --notebook-dir=/
}

# Main 
# 调用 MLX 安装函数
install_mlx

# 调用 MLX 启动函数
start_mlx

# 总体计时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo "所有任务完成，总耗时: ${TOTAL_TIME} 秒"

echo "Apple mlx 安装完成"