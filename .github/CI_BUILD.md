# CI 打包说明

## 触发方式

| 触发条件 | 行为 |
|---------|------|
| 推送到 `main`/`master` | 构建 APK，上传为 Actions 产物 |
| 推送 `v*` 标签 | 构建 APK + 创建 GitHub Release |
| 手动触发 (workflow_dispatch) | 构建 APK，可选创建 Release |

## 构建产物

每次构建会生成 4 个 APK：

| 文件 | 说明 |
|------|------|
| `app-armeabi-v7a-release.apk` | 32 位 ARM (旧设备) |
| `app-arm64-v8a-release.apk` | 64 位 ARM (主流设备) |
| `app-x86_64-release.apk` | x86_64 (模拟器) |
| `app-release.apk` | 通用包 (包含所有架构) |

## 签名配置 (必需)

### 1. 生成签名密钥

```bash
keytool -genkey -v \
  -keystore keystore.jks \
  -keyalg RSA -keysize 2048 -validity 36500 \
  -alias tw-key
```

按提示输入：
- keystore 密码
- key 别名 (如 `tw-key`)
- key 密码
- 姓名/组织等信息

### 2. 配置 GitHub Secrets

在仓库 **Settings → Secrets and variables → Actions** 中添加以下 4 个 Secret：

| Secret 名称 | 值 |
|-------------|---|
| `KEYSTORE_BASE64` | keystore.jks 的 Base64 编码 (见下方命令) |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_ALIAS` | key 别名 |
| `KEY_PASSWORD` | key 密码 |

生成 Base64 编码：

```bash
# Linux / macOS
base64 -i keystore.jks | tr -d '\n'

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("keystore.jks"))
```

### 3. 本地构建签名

如需本地构建签名 APK，在 `android/` 目录下创建 `key.properties`：

```properties
storeFile=app/keystore.jks
storePassword=你的keystore密码
keyAlias=你的key别名
keyPassword=你的key密码
```

然后将 `keystore.jks` 放到 `android/app/` 目录下，执行：

```bash
flutter build apk --release
```

## 手动触发构建

1. 进入仓库 **Actions** 页面
2. 选择 **Build & Release APK** 工作流
3. 点击 **Run workflow**
4. 可选择是否创建 GitHub Release

## 打 Tag 发布 Release

```bash
git tag v1.1.0
git push origin v1.1.0
```

推送 tag 后会自动构建并创建 Release，APK 会附加到 Release 中。
