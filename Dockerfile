# 使用官方Python镜像
FROM python:3.12-slim

# 设置工作目录
WORKDIR /app

# 复制依赖文件并安装
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . .

# 暴露端口
EXPOSE 5000

# 使用 Gunicorn 运行应用（生产环境）
# `-b`：绑定地址和端口
# `app:app`：第一个`app`是您的Python模块文件名（app.py），第二个`app`是Flask应用实例名
# `--workers`：工作进程数，建议设置为 (2 * CPU核心数) + 1。这里设为4是一个通用起始值。
# `--preload`：可选，加速启动并节省内存。
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app", "--workers", "4"]