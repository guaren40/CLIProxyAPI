# Zeabur ARM64 部署

本仓库根目录的 `Dockerfile` 将构建阶段和最终镜像都固定为 `linux/arm64`，只产出 ARM64 镜像，运行节点必须为 ARM64。Zeabur 选择本 GitHub 仓库的 `main` 分支即可识别 Dockerfile；无需填写构建参数、环境变量或上传 `config.yaml`。Zeabur 的构建环境还必须能够执行 ARM64 构建阶段；如果不能，构建会直接失败，不会生成其他架构的镜像。

完整的一键部署模板保存在 [`zeabur-template.yaml`](zeabur-template.yaml)。它指定本仓库的 GitHub 仓库 ID、8317 HTTP 端口、持久的 `/data` 卷，并自动生成两枚独立随机密钥。将该模板导入 Zeabur 后，选择或生成域名并部署即可；部署后在首次启动日志，或在 Zeabur 文件管理器的 `/data/initial-credentials.txt` 中查看 API Key 和管理密钥。模板必须先在 Zeabur 导入或发布，单纯把 YAML 放在 GitHub 不会自动创建 Zeabur 的部署按钮。

若直接通过 Zeabur 的 GitHub 服务部署，首次启动也会自动生成配置与密钥，可在首次启动日志中查看，或在容器 `/data/initial-credentials.txt` 中读取。普通 GitHub 部署不会自动挂载持久卷；要让登录凭据和密钥跨重新部署保存，应使用上述模板。不要把 `/data` 中的配置和密钥提交到仓库。

管理界面地址为 `https://你的域名/management.html`。管理密钥用于登录管理界面，API Key 用于客户端请求。你仍需在管理界面添加所用模型供应商的登录凭据或上游密钥。

本仓库的 [上游同步工作流](.github/workflows/sync-upstream.yml) 每 5 分钟检查 `router-for-me/CLIProxyAPI` 的 `main` 分支。发现新提交后，合并上游源码，保留本仓库的 Dockerfile、部署脚本、Zeabur 模板和工作流；ARM64 镜像构建通过后才推送本仓库 `main`，Zeabur 关联该分支后会随推送重新部署。GitHub 定时任务可能延迟或漏跑，合并冲突、构建失败或分支保护也会阻止推送。由于本仓库是 fork，若 GitHub 的 Actions 页面显示工作流已停用，需要在该页面启用；启用前不会自动同步。
