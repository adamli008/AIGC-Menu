#!/bin/bash

#本脚本是安装Comfyui 
clear

# 定义参数路径
aigc_dir="/Volumes/AIGC/"
software_dir="/Volumes/AIGC/software/"

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

# 定义函数统计时间
function execute_with_time {
    local start=$SECONDS
    echo "开始执行: $1"
    bash "$1"
    local end=$SECONDS
    echo "完成: $1，耗时 $((end - start)) 秒"

    # 当前累计耗时
    local current_total=$(( $(date +%s) - START_TIME ))
    echo "目前为止累计耗时: ${current_total} 秒"
}

#!/bin/bash
export NONINTERACTIVE=1

# 使用变量作为口令
echo "**************"
echo "欢迎使用AIGC安装"
echo "**************"

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

# 函数：安装 Python（离线版）
install_python() {
    echo "正在安装 Python..."
    current_python_full_version=$(python3 --version 2>&1 | awk '{print $2}')

    if [ -z "$current_python_full_version" ]; then
        echo "无法获取当前Python版本。"
        exit 1
    else
        echo "目前Python 版本 \"$current_python_full_version\""
    fi

    current_python_major_version=$(echo "$current_python_full_version" | awk -F. '{print $1}')
    current_python_minor_version=$(echo "$current_python_full_version" | awk -F. '{print $2}')
    current_python_version=$((10#$current_python_major_version * 1000 + 10#$current_python_minor_version))

    target_version=3011 # 3.11的整数表示

    if [ "$current_python_version" -lt "$target_version" ]; then
        echo "当前Python版本低于3.11，需要安装Python 3.12"
        sudo -S installer -verboseR -pkg "$software_dir"python_202323.pkg -target /
        # 添加Python和pip的link
    	if [ -L "/usr/local/bin/python" ] || [ -e "/usr/local/bin/python" ]; then
        	echo "移除现有的 Python 链接..."
        	sudo -S rm /usr/local/bin/python
    	fi

    	if [ -L "/usr/local/bin/pip" ] || [ -e "/usr/local/bin/pip" ]; then
        	echo "移除现有的 pip 链接..."
        	sudo -S rm /usr/local/bin/pip
    	fi

   	 	# 添加Python和pip的link
    	sudo -S ln -s /usr/local/bin/python3 /usr/local/bin/python
    	sudo -S ln -s /usr/local/bin/pip3 /usr/local/bin/pip

    else
        echo "当前Python版本高于或等于3.11，无需安装。"
    fi


    python --version || { echo "Python installation failed"; exit 1; }
    pip --version || { echo "pip installation failed"; exit 1; }
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

# 函数：install-Comfyui 
install_Comfyui() {

	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"
	aigc_dir="/Volumes/AIGC/"

	echo "正在调用zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 添加conda到PATH环境变量
	echo "正在配置conda环境变量..."
	export PATH=$HOME/miniconda3/condabin:$PATH

	# 创建python环境并安装torch等依赖
	echo "正在创建Python环境并安装依赖..."
#	conda deactivate || { echo "退出conda环境失败"; exit 1; }
	conda config --set offline true || { echo "设置conda离线模式失败"; exit 1; }
	
#	conda create -n comfyui python=3.12 -y || { echo "创建conda环境comfyui失败"; exit 1; }	
	cd $HOME/miniconda3/envs || { echo "切换到miniconda3 env目录失败"; exit 1; }
	mkdir -p comfyui || { echo "创建envs下的comfyui目录失败"; exit 1; }
	tar -xvzf /Volumes/AIGC/software/py312.tar.gz -C ~/miniconda3/envs/comfyui || { echo "解包chatchat03数据包失败"; exit 1; }
	echo "解包comfyui成功"
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
	$HOME/miniconda3/envs/comfyui/bin/conda-unpack || { echo "移除mlx绑定失败"; exit 1; }
	echo "移除comfyui绑定成功"

	# 激活新创建的环境
	echo "正在激活Python环境..."
	conda activate comfyui || { echo "激活conda环境comfyui失败"; exit 1; }

	# 复制PyTorch文件到指定目录
	echo "正在复制PyTorch文件..."
	mkdir -p ~/PyTorch || { echo "创建PyTorch目录失败"; exit 1; }
	cp -r "${lab_dir}PyTorch/"* ~/PyTorch/ || { echo "复制PyTorch文件失败"; exit 1; }

	# 设置pip的wheel文件链接目录	
	export PIP_FIND_LINKS="$HOME/PyTorch"
	echo "正在安装torch、torchvision和torchaudio..."
	pip3 install --pre torch torchvision torchaudio --no-index || { echo "安装torch、torchvision和torchaudio失败"; exit 1; }

	# 复制模型文件
	echo "正在复制模型文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	mkdir -p ~/Flux_models || { echo "创建Flux_models目录失败"; exit 1; }
	cp -r "${aigc_dir}Flux_models/"* ~/Flux_models/ || { echo "复制Flux_models文件失败"; exit 1; }

	mkdir -p ~/ComfyUI || { echo "创建ComfyUI目录失败"; exit 1; }
	cp -r ${lab_dir}ComfyUI/* ~/ComfyUI/ || { echo "复制ComfyUI文件失败"; exit 1; }

	mkdir -p ~/comfyui-requirements-file || { echo "创建comfyui-requirements-file目录失败"; exit 1; }
	cp -r "${lab_dir}comfyui-requirements-file/"* ~/comfyui-requirements-file/ || { echo "复制comfyui-requirements-file文件失败"; exit 1; }

	# 克隆ComfyUI软件并安装依赖
	echo "正在克隆ComfyUI软件并安装依赖..."
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	conda deactivate || { echo "退出conda环境失败"; exit 1; }
	conda config --set offline true || { echo "设置conda离线模式失败"; exit 1; }
	conda activate comfyui || { echo "激活conda环境comfyui失败"; exit 1; }
	cd ~/comfyui-requirements-file || { echo "进入comfyui-requirements-file目录失败"; exit 1; }

	echo "正在安装ComfyUI依赖..."
	pip install *.whl || { echo "安装ComfyUI依赖失败"; exit 1; }
	rm -rf ~/comfyui-requirements-file || { echo "删除comfyui-requirements-file目录失败"; exit 1; }

	# 安装ComfyUI manager自定义节点
	echo "正在安装ComfyUI manager自定义节点..."
	cd ~/ComfyUI/custom_nodes || { echo "进入ComfyUI/custom_nodes目录失败"; exit 1; }
	unzip -o ${lab_dir}ComfyUI-Manager.zip -d ~/ComfyUI/custom_nodes/ -x "__MACOSX/*" || { echo "解压ComfyUI-Manager.zip失败"; exit 1; }
	echo "正在安装ComfyUI manager依赖文件..."
	mkdir -p ~/comfyui-manager-requirements-file || { echo "创建comfyui-manager-requirements-file目录失败"; exit 1; }
	cp -r "${lab_dir}comfyui-manager-requirements-file/"* ~/comfyui-manager-requirements-file/ || { echo "复制comfyui-manager-requirements-file文件失败"; exit 1; }
	cd  ~/comfyui-manager-requirements-file/ || { echo "进入comfyui-manager-requirements-file目录失败"; exit 1; }
	pip install *.whl || { echo "安装ComfyUI manager依赖失败"; exit 1; }
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/comfyui-manager-requirements-file || { echo "删除comfyui-manager-requirements-file目录失败"; exit 1; }

    # 安装 Comfyui Manager 依赖项 gitpython
	if pip show gitpython &> /dev/null; then
    	echo "GitPython is already installed."
	else
    	echo "GitPython is not installed. Now install it."
    	echo "pip install gitpython"   
    	# 创建临时目录
    	mkdir -p ~/GitPython || { echo "创建临时GitPython目录失败"; exit 1; }    
   	 	# 复制 whl 文件
    	cp -r "/Volumes/AIGC/lab/GitPython/"* ~/GitPython || { echo "复制 whl 文件失败"; exit 1; }
    	# 进入临时目录
    	cd ~/GitPython || { echo "进入临时GitPython目录失败"; exit 1; }
    	# 安装 whl 文件
    	pip install --force-reinstall *.whl || { echo "安装 whl 文件失败"; exit 1; }
    	echo "ComfyUI-Manager: installing dependencies GitPython has done."
    	# 返回到家目录
    	cd ~ || { echo "返回到家目录失败"; exit 1; }
    	# 删除临时目录
    	rm -rf ~/GitPython || { echo "删除临时GitPython目录失败"; exit 1; }
	fi


	# 安装语言翻译自定义节点
	echo "正在安装语言翻译自定义节点..."
	cd ~/ComfyUI/custom_nodes || { echo "进入ComfyUI/custom_nodes目录失败"; exit 1; }
	mkdir -p ~/ComfyUI/custom_nodes/AIGODLIKE-COMFYUI-TRANSLATION || { echo "创建AIGODLIKE-COMFYUI-TRANSLATION目录失败"; exit 1; }
	cp -r "${lab_dir}AIGODLIKE-COMFYUI-TRANSLATION/"* ~/ComfyUI/custom_nodes/AIGODLIKE-COMFYUI-TRANSLATION/ || { echo "复制AIGODLIKE-COMFYUI-TRANSLATION文件失败"; exit 1; }

	# 部署Flux模型文件
	echo "正在部署Flux模型文件..."
	mv ~/Flux_models/checkpoints/* ~/ComfyUI/models/checkpoints/ || { echo "移动checkpoints文件失败"; exit 1; }
	mv ~/Flux_models/clip/* ~/ComfyUI/models/clip/ || { echo "移动clip文件失败"; exit 1; }
	#mv ~/Flux_models/loras/* ~/ComfyUI/models/loras/ || { echo "移动loras文件失败"; exit 1; }
	cp -r ~/Flux_models/loras/* ~/ComfyUI/models/loras/ || { echo "移动loras文件失败"; exit 1; }
	mv ~/Flux_models/unet/* ~/ComfyUI/models/unet/ || { echo "移动unet文件失败"; exit 1; }
	mv ~/Flux_models/vae/* ~/ComfyUI/models/vae/ || { echo "移动vae文件失败"; exit 1; }
	mv ~/Flux_models/upscale_models/* ~/ComfyUI/models/upscale_models/ || { echo "移动upscale_models文件失败"; exit 1; }
	mkdir -p ~/ComfyUI/models/xlabs/controlnets || { echo "创建xlabs/controlnets目录失败"; exit 1; }
	mv ~/Flux_models/xlabs-controlnet/* ~/ComfyUI/models/xlabs/controlnets/ || { echo "移动xlabs-controlnet文件失败"; exit 1; }
	echo "部署Flux模型文件完成..."

	# 部署样本工作流
	echo "正在部署样本工作流..."
	mkdir -p ~/ComfyUI/sample_workflows || { echo "创建sample_workflows目录失败"; exit 1; }
	mv ~/Flux_models/ComfyUI_workflows/* ~/ComfyUI/sample_workflows/ || { echo "移动ComfyUI_workflows文件失败"; exit 1; }

	# 安装图像比较自定义节点
	echo "正在安装图像比较自定义节点..."
	mkdir -p ~/ComfyUI/custom_nodes/rgthree-comfy || { echo "创建rgthree-comfy目录失败"; exit 1; }
	cp -r "${lab_dir}rgthree-comfy/"* ~/ComfyUI/custom_nodes/rgthree-comfy/ || { echo "复制rgthree-comfy文件失败"; exit 1; }

	echo "*********************."
	echo "Comfyui 安装完成......."
	echo "*********************."
}

# 函数：install-asitop
install_asitop() {
	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 安装 macOS 资源监测软件 asitop 
	echo "正在安装 macOS 资源监测软件：asitop ..."

	# 退出当前激活的conda环境
	conda deactivate || { echo "退出当前conda环境失败"; exit 1; }

	# 创建名为asitop的新conda环境，并指定Python版本为3.12
#	conda create -n asitop python=3.12 -y || { echo "创建conda环境失败"; exit 1; }
	cd $HOME/miniconda3/envs || { echo "切换到miniconda3 env目录失败"; exit 1; }
	mkdir -p asitop || { echo "创建envs下的asitop目录失败"; exit 1; }
	tar -xvzf /Volumes/AIGC/software/py312.tar.gz -C ~/miniconda3/envs/asitop || { echo "解包asitop数据包失败"; exit 1; }
	echo "解包asitop成功"
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }
	$HOME/miniconda3/envs/asitop/bin/conda-unpack || { echo "移除asitop绑定失败"; exit 1; }
	echo "移除asitop绑定成功"


	# 激活asitop环境
	conda activate asitop || { echo "激活conda环境失败"; exit 1; }

	# 在用户目录下创建asitop文件夹
	mkdir -p ~/asitop || { echo "创建asitop目录失败"; exit 1; }

	# 复制软件文件到用户目录下的asitop文件夹
	echo "复制asitop软件文件..."
	cp -r "${lab_dir}asitop/"* ~/asitop/ || { echo "复制asitop软件文件失败"; exit 1; }

	# 进入asitop目录
	cd ~/asitop || { echo "进入asitop目录失败"; exit 1; }

	# 使用pip安装asitop，不使用索引，而是使用本地链接
	echo "使用pip安装asitop..."
	pip install --no-index --find-links=. asitop || { echo "pip安装asitop失败"; exit 1; }

	# 返回到用户目录
	cd ~ || { echo "返回到用户目录失败"; exit 1; }

	# 删除asitop文件夹，清理临时文件
	echo "清理临时文件..."
	rm -rf ~/asitop || { echo "清理临时文件失败"; exit 1; }
}

# 函数：install-flux
install_flux() {
	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 安装MLX Flux支持
	echo "正在安装MLX Flux支持..."
	conda deactivate || { echo "退出当前conda环境失败"; exit 1; }
	conda activate comfyui || { echo "激活comfyui环境失败"; exit 1; }

	# 离线安装uv
	echo "正在执行离线安装uv..."
	WHEELS_DIR="$HOME/uv_install"  # 定义存放wheel文件的目录
	mkdir -p "${WHEELS_DIR}" || { echo "创建wheel文件目录失败"; exit 1; }  # 创建wheel文件目录
	echo "复制uv安装文件..."
	cp -r "${lab_dir}uv_install/"* "${WHEELS_DIR}" || { echo "复制wheel文件到指定目录失败"; exit 1; }  # 复制wheel文件到指定目录
	echo "进入wheel文件目录..."
	cd "${WHEELS_DIR}" || { echo "进入wheel文件目录失败"; exit 1; }  # 进入wheel文件目录
	echo "使用pip安装uv..."
	pip install --no-index --find-links=. uv || { echo "从本地wheel文件安装uv失败"; exit 1; }  # 从本地wheel文件安装uv
	cd ~ || { echo "返回到家目录失败"; exit 1; }  # 返回到家目录
	echo "清理临时文件..."
	rm -rf "${WHEELS_DIR}" || { echo "删除临时wheel文件目录失败"; exit 1; }  # 删除临时wheel文件目录

	# 安装MFlux
	echo "正在安装MFlux..."
	# 导出本地bin目录到PATH，以便执行uv工具
	export PATH=$HOME/.local/bin:$PATH
	echo "使用uv tool安装MFlux..."
#	uv tool install --upgrade mflux || { echo "使用uv tool安装或升级mflux失败"; exit 1; }  # 使用uv tool安装或升级mflux
#	uv tool update-shell || { echo "更新shell配置失败"; exit 1; }  # 更新shell配置
    mkdir -p ~/mflux || { echo "创建MFlux目录失败"; exit 1; }
	cp -r "${lab_dir}mflux/"* ~/mflux/ || { echo "复制MFlux文件失败"; exit 1; }
	cd ~/mflux
#	uv tool install --upgrade ./mflux-0.4.1-py3-none-any.whl || { echo "使用uv tool安装或升级mflux失败"; exit 1; }  # 使用uv tool安装或升级mflux
	uv tool install --no-index --find-links=$HOME/mflux mflux || { echo "使用uv tool安装或升级mflux失败"; exit 1; }  # 使用uv tool安装或升级mflux
	uv tool update-shell || { echo "更新shell配置失败"; exit 1; }  # 更新shell配置
	cd ~ || { echo "返回到家目录失败"; exit 1; }  # 返回到家目录
	echo "清理临时文件..."
	rm -rf ~/mflux || { echo "删除临时mflux文件目录失败"; exit 1; }  # 删除临时mflux文件目录

	# 测试mflux
	# echo "正在测试mflux..."
	# export PATH=$HOME/.local/bin:$PATH  # 再次导出PATH，确保mflux可执行
	# echo "执行mflux生成测试..."
	# mflux-generate --model schnell --prompt "Luxury food photograph" --steps 2 --seed 2 -q 8 || { echo "测试mflux命令失败"; exit 1; }  # 测试mflux命令
}


# 函数：install-MLX
install_MLX() {
	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 安装 Apple MLX framework
	echo "正在安装 Apple MLX framework..."
	conda deactivate || { echo "退出当前conda环境失败"; exit 1; }
	conda create -n mlx python=3.12 -y || { echo "创建conda环境mlx失败"; exit 1; }
	conda activate mlx || { echo "激活conda环境mlx失败"; exit 1; }

	# 复制MLX相关文件到用户目录
	echo "正在复制MLX相关文件..."
	mkdir -p ~/mlx || { echo "创建MLX目录失败"; exit 1; }
	cp -r "${lab_dir}mlx/"* ~/mlx/ || { echo "复制MLX文件失败"; exit 1; }

	# 进入MLX目录并安装MLX
	echo "正在安装 mlx 和 mlx-lm..."
	cd ~/mlx/ || { echo "进入MLX目录失败"; exit 1; }
	pip install --no-index --find-links=. mlx || { echo "pip安装mlx失败"; exit 1; }

	# 清理临时文件
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/mlx || { echo "删除临时MLX目录失败"; exit 1; }

	# 复制MLX-LM相关文件到用户目录
	echo "正在复制MLX-LM相关文件..."
	mkdir -p ~/mlx-lm || { echo "创建MLX-LM目录失败"; exit 1; }
	cp -r "${lab_dir}mlx-lm/"* ~/mlx-lm/ || { echo "复制MLX-LM文件失败"; exit 1; }

	# 进入MLX-LM目录并安装MLX-LM
	cd ~/mlx-lm/ || { echo "进入MLX-LM目录失败"; exit 1; }
	pip install --no-index --find-links=. mlx-lm || { echo "pip安装mlx-lm失败"; exit 1; }

	# 清理临时文件
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/mlx-lm || { echo "删除临时MLX-LM目录失败"; exit 1; }

	# 复制MLX Examples相关文件到用户目录
	echo "正在复制MLX Examples相关文件..."
	mkdir -p ~/mlx-examples || { echo "创建MLX Examples目录失败"; exit 1; }
	cp -r "${lab_dir}mlx-examples/"* ~/mlx-examples/ || { echo "复制MLX Examples文件失败"; exit 1; }

	# 安装MLX Examples依赖（注释掉的命令可以根据需要取消注释并执行）
	# cd ~/mlx-examples || { echo "进入MLX Examples目录失败"; exit 1; }
	# pip install -r ./llms/llama/requirements.txt || { echo "安装LLaMA依赖失败"; exit 1; }
	# pip install -r ./llms/mlx_lm/requirements.txt || { echo "安装MLX-LM依赖失败"; exit 1; }
	# pip install -r ./stable_diffusion/requirements.txt || { echo "安装Stable Diffusion依赖失败"; exit 1; }
	# pip install -r ./flux/requirements.txt || { echo "安装Flux依赖失败"; exit 1; }
	# pip install -r ./llava/requirements.txt || { echo "安装LLaVA依赖失败"; exit 1; }

	# 复制LLaMA依赖文件
	echo "正在复制LLaMA依赖文件..."
	mkdir ~/llms-llama-req || { echo "创建LLaMA依赖目录失败"; exit 1; }
	cp -r "${lab_dir}llms-llama-req/"* ~/llms-llama-req/ || { echo "复制LLaMA依赖文件失败"; exit 1; }
	cd ~/llms-llama-req || { echo "进入LLaMA依赖目录失败"; exit 1; }
	pip install *.whl || { echo "安装LLaMA依赖失败"; exit 1; }
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/llms-llama-req || { echo "删除临时LLaMA依赖目录失败"; exit 1; }

	# 复制MLX-LM依赖文件
	echo "正在复制MLX-LM依赖文件..."
	mkdir -p ~/llms-mlx_lm-req || { echo "创建MLX-LM依赖目录失败"; exit 1; }
	cp -r "${lab_dir}llms-mlx_lm-req/"* ~/llms-mlx_lm-req/ || { echo "复制MLX-LM依赖文件失败"; exit 1; }
	cd ~/llms-mlx_lm-req || { echo "进入MLX-LM依赖目录失败"; exit 1; }
	pip install *.whl || { echo "安装MLX-LM依赖失败"; exit 1; }
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/llms-mlx_lm-req || { echo "删除临时MLX-LM依赖目录失败"; exit 1; }

	# 复制Stable Diffusion依赖文件
	echo "正在复制Stable Diffusion依赖文件..."
	mkdir -p ~/stable_diffusion-req || { echo "创建Stable Diffusion依赖目录失败"; exit 1; }
	cp -r "${lab_dir}stable_diffusion-req/"* ~/stable_diffusion-req/ || { echo "复制Stable Diffusion依赖文件失败"; exit 1; }
	cd ~/stable_diffusion-req || { echo "进入Stable Diffusion依赖目录失败"; exit 1; }
	pip install *.whl || { echo "安装Stable Diffusion依赖失败"; exit 1; }
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/stable_diffusion-req || { echo "删除临时Stable Diffusion依赖目录失败"; exit 1; }

	# 复制Flux依赖文件
	echo "正在复制Flux依赖文件..."
	mkdir -p ~/flux-req || { echo "创建Flux依赖目录失败"; exit 1; }
	cp -r "${lab_dir}flux-req/"* ~/flux-req/ || { echo "复制Flux依赖文件失败"; exit 1; }
	cd ~/flux-req || { echo "进入Flux依赖目录失败"; exit 1; }
	pip install *.whl || { echo "安装Flux依赖失败"; exit 1; }
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/flux-req || { echo "删除临时Flux依赖目录失败"; exit 1; }

	# 复制LLaVA依赖文件
	echo "正在复制LLaVA依赖文件..."
	mkdir -p ~/llava-req || { echo "创建LLaVA依赖目录失败"; exit 1; }
	cp -r "${lab_dir}llava-req/"* ~/llava-req/ || { echo "复制LLaVA依赖文件失败"; exit 1; }
	cd ~/llava-req || { echo "进入LLaVA依赖目录失败"; exit 1; }
	pip install *.whl || { echo "安装LLaVA依赖失败"; exit 1; }
	cd ~ || { echo "返回到家目录失败"; exit 1; }
	rm -rf ~/llava-req || { echo "删除临时LLaVA依赖目录失败"; exit 1; }

	echo "MLX framework 和相关依赖安装完成。"
}

# 函数：install-ffmpeg
install_ffmpeg() {
	# 定义变量
	FFMPEG_VERSION="7.1"
	FFMPEG_TAR_XZ="ffmpeg-$FFMPEG_VERSION.tar.xz"
	FFMPEG_URL="https://ffmpeg.org/releases/$FFMPEG_TAR_XZ"  # FFmpeg官方下载链接
	DOWNLOAD_DIR="$HOME/Downloads"  # 替换为你的下载目录
	INSTALL_PREFIX="/usr/local"  # 安装前缀

	# 复制Fmpeg源代码到下载目录
	echo "正在复制FFmpeg源代码..."
	cp /Volumes/AIGC/software/$FFMPEG_TAR_XZ $DOWNLOAD_DIR || { echo "复制FFmpeg源代码失败"; exit 1; }

	# 解压缩源代码
	echo "正在解压缩FFmpeg源代码..."
	tar -xf "$DOWNLOAD_DIR/$FFMPEG_TAR_XZ" -C "$DOWNLOAD_DIR" || { echo "解压缩FFmpeg源代码失败"; exit 1; }

	# 进入解压缩后的目录
	FFMPEG_DIR="$DOWNLOAD_DIR/ffmpeg-$FFMPEG_VERSION"
	echo "进入FFmpeg源代码目录..."
	cd "$FFMPEG_DIR" || { echo "进入FFmpeg源代码目录失败"; exit 1; }

	# 配置构建环境
	echo "配置FFmpeg构建环境..."
	./configure --prefix="$INSTALL_PREFIX" || { echo "配置FFmpeg构建环境失败"; exit 1; }
#	./configure --prefix="$INSTALL_PREFIX" --disable-x86asm || { echo "配置FFmpeg构建环境失败"; exit 1; }

	# 编译FFmpeg
	echo "编译FFmpeg..."
	make -j$(sysctl -n hw.logicalcpu) || { echo "编译FFmpeg失败"; exit 1; }

	# 安装FFmpeg
	echo "安装FFmpeg..."
	sudo make install || { echo "安装FFmpeg失败"; exit 1; }

	# 验证安装
	echo "验证FFmpeg安装..."
	ffmpeg -version || { echo "FFmpeg安装验证失败"; exit 1; }

	# 删除安装文件和源代码
	echo "清理安装文件和源代码..."
	cd ~ || { echo "返回到家目录失败"; exit 1; }  # 返回到家目录
	rm -rf $FFMPEG_DIR || { echo "删除FFmpeg目录失败"; exit 1; }
	rm "$DOWNLOAD_DIR/$FFMPEG_TAR_XZ" || { echo "删除FFmpeg源代码文件失败"; exit 1; }

	echo "FFmpeg安装完成。"
}

# 函数：install-whisper
install_whisper() {
	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 安装 mlx-whisper
	echo "正在安装 mlx-whisper..."
	# pip install mlx-whisper  

	# 离线安装 mlx-whisper
	echo "正在执行mlx-whisper的离线安装..."
	mkdir -p ~/mlx-whisper || { echo "创建mlx-whisper目录失败"; exit 1; }  
	cp -r "${lab_dir}mlx-whisper/"* ~/mlx-whisper/ || { echo "复制mlx-whisper文件到目录失败"; exit 1; }  
	cd ~/mlx-whisper || { echo "进入mlx-whisper目录失败"; exit 1; }  
	pip install --no-index --find-links=. mlx-whisper || { echo "从本地安装mlx-whisper失败"; exit 1; } 
	cd ~ || { echo "返回到家目录失败"; exit 1; } 
	rm -rf ~/mlx-whisper || { echo "删除临时mlx-whisper目录失败"; exit 1; }  

	echo "mlx-whisper 安装完成。"
}

# 函数：install-huggingface
install_huggingface() {
	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 安装 huggingface_hub 和 hf_transfer
	echo "正在安装 huggingface_hub 和 hf_transfer..."
	# 创建huggingface_packages目录
	mkdir -p ~/huggingface_packages || { echo "创建huggingface_packages目录失败"; exit 1; } 
	# 复制huggingface_packages文件到目录
	cp -r "${lab_dir}huggingface_packages/"* ~/huggingface_packages/ || { echo "复制huggingface_packages文件到目录失败"; exit 1; }  
	cd ~/huggingface_packages || { echo "进入huggingface_packages目录失败"; exit 1; }  
	# 从本地安装huggingface_hub hf_transfer
	pip install --no-index --find-links=. huggingface_hub hf_transfer || { echo "从本地安装huggingface_hub hf_transfer失败"; exit 1; } 

	echo "hugging face 组件 安装完成..."
	cd ~ || { echo "返回到家目录失败"; exit 1; } 
	rm -rf ~/huggingface_packages || { echo "删除临时huggingface_packages目录失败"; exit 1; } 

	# 启用 HF_TRANSFER
	echo "启用 HF_TRANSFER..."
	export HF_HUB_ENABLE_HF_TRANSFER=1 || { echo "设置HF_HUB_ENABLE_HF_TRANSFER环境变量失败"; exit 1; }
}

# 函数：copy-models
copy_models() {
	# 定义软件存放目录变量
	lab_dir="/Volumes/AIGC/lab/"

	# 载入zsh配置文件，确保conda命令可用
	echo "载入zsh配置文件..."
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 创建模型目录并复制Qwen模型
	echo "正在创建模型目录并复制Qwen模型..."
	mkdir -p ~/models || { echo "创建模型目录失败"; exit 1; }

	# 从U盘复制huggingface.zip并解压缩到~/.cache目录
	echo "从U盘复制huggingface.zip并解压缩到~/.cache目录..."
	unzip -o "${lab_dir}huggingface.zip" -d ~/.cache -x "__MACOSX/*" || { echo "解压缩huggingface.zip失败"; exit 1; }

	# 从U盘复制models.zip并解压缩到用户主目录
	echo "从U盘复制models.zip并解压缩到用户主目录..."
	unzip -o "${lab_dir}models.zip" -d ~/ -x "__MACOSX/*" || { echo "解压缩models.zip失败"; exit 1; }
}

install_full_Comfyui() {
	#!/bin/bash

	# 定义环境目录变量
	ENV_DIR="$HOME/miniconda3/envs/comfyui"

	# 使用if语句判断目录是否存在
	if [ -d "$ENV_DIR" ]; then
    	echo " comfyui 已经安装，可以开始运行"
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

		echo "开始安装 python..."
		install_python

		echo "开始安装 Miniconda..."
		install_miniconda

		echo "*******************************************"
		echo "Xcode CLT/HomeBrew/Miniconda 基础软件安装完成。"
		echo "*******************************************"

		echo "2/9 安装Comfyui..."
		install_Comfyui

		echo "3/9 安装asitop..."
		install_asitop

		echo "4/9 安装FLUX..."
		install_flux

		echo "5/9 安装MLX..."
		install_MLX

		echo "6/9 安装ffmpeg..."
		arch -arm64 bash -c "$(declare -f install-ffmpeg); install-ffmpeg"
		#install-ffmpeg

		echo "7/9 安装whisper..."
		install_whisper

		echo "8/9 安装huggingface..."
		install_huggingface

		echo "9/9 复制模型..."
		copy_models
	fi
}

#此函数是用来启动comfyui 
start_full_Comfyui() {
	#!/bin/bash

	
	# 设置 Miniconda 路径
	source ~/.zshrc || { echo "重新加载 zshrc 失败"; exit 1; }

	# 检查 conda 是否安装
	if ! command -v conda &> /dev/null; then
    	echo "Conda 未安装，请先安装 Conda 后再运行此脚本。"
    	exit 1
	else
    	echo "Conda 已安装，继续执行后续操作。"
	fi

	conda info --envs || { echo "获取conda环境列表失败"; exit 1; }

	# 指定conda环境的名称
	ENV_COMFYUI="comfyui"
	ENV_MLX="mlx"
	ENV_ASITOP="asitop"

	# 检查 ~/ComfyUI 文件是否存在
	if [ ! -d ~/ComfyUI ]; then
    	echo "ComfyUI 文件不存在, 请先安装。"
    	exit 1
	fi

	# 定义一个函数来检查特定的conda环境是否已经被激活
	check_and_activate_env() {
  	local env_name=$1
  	# 使用 conda info --envs 检查环境是否激活
  	if conda info --envs | grep -q "^/*.*$env_name"; then
    	echo "Conda environment '$env_name' is already active."
  	else
    	echo "Activating conda environment '$env_name'..."
    	source ~/miniconda3/etc/profile.d/conda.sh || { echo "源conda配置失败"; exit 1; }
    	conda activate "$env_name" || { echo "激活conda环境 '$env_name' 失败"; exit 1; }
  	fi
	}

	# 检查并激活 asitop 环境
	check_and_activate_env "$ENV_ASITOP"

	# 检查并激活 mlx 环境
	check_and_activate_env "$ENV_MLX"

	# 检查并激活 ComfyUI 环境
	check_and_activate_env "$ENV_COMFYUI"

	# 启动 ComfyUI 并在后台运行
	echo "Starting ComfyUI..."
	source ~/miniconda3/etc/profile.d/conda.sh || { echo "源conda配置失败"; exit 1; }
	conda activate comfyui || { echo "激活conda环境 comfyui 失败"; exit 1; }
	    
	# 检测是否有正在运行的 python 进程并终止
	PYTHON_RUNNING_PIDS=$(pgrep -f "python")  # 检测所有运行中的 Python 进程
	if [ -n "$PYTHON_RUNNING_PIDS" ]; then
  		echo "检测到以下正在运行的 Python 进程：$PYTHON_RUNNING_PIDS"
  		for PID in $PYTHON_RUNNING_PIDS; do
    	sudo kill -9 "$PID" || { echo "无法终止 Python 进程 PID: $PID"; exit 1; }
    	echo "已终止 Comfyui Python 进程 PID: $PID"
  		done
	else
  		echo "未检测到正在运行的 Comfyui 进程"
	fi
	
	cd $HOME/comfyui || { echo "进入comfyui目录失败"; exit 1; }
	python main.py &  # 后台运行 ComfyUI
	COMFYUI_PID=$!    # 保存进程ID

	# 等待 ComfyUI 服务启动并检查 http://127.0.0.1:8188 是否可访问
	echo "Waiting for ComfyUI to become available at http://127.0.0.1:8188..."
	until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:8188); do
  		printf '.'
  		sleep 1
	done

	# 打开 Safari 并访问指定地址
	echo "ComfyUI is now available. Opening Safari to visit http://127.0.0.1:8188"
	open -a Safari "http://127.0.0.1:8188" || { echo "打开Safari失败"; exit 1; }

	# 等待 ComfyUI 进程完成，保持脚本运行
	wait $COMFYUI_PID || { echo "等待ComfyUI进程完成失败"; exit 1; }

}

# Main 
# 调用 Comfyui 安装函数
install_full_Comfyui

# 调用 Comfyui 启动函数
start_full_Comfyui

# 总体计时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo "所有任务完成，总耗时: ${TOTAL_TIME} 秒"



