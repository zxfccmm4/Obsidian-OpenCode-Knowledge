# 贡献指南 / Contributing Guide

感谢你对这个项目的兴趣！无论你是技术高手还是刚入门的新手，都欢迎参与贡献。

Thank you for your interest in this project! Whether you're a seasoned developer or just getting started, your contributions are welcome.

---

## 📋 目录 / Table of Contents

- [如何贡献 / How to Contribute](#如何贡献--how-to-contribute)
- [开发环境搭建 / Development Setup](#开发环境搭建--development-setup)
- [代码规范 / Code Guidelines](#代码规范--code-guidelines)
- [提交信息格式 / Commit Message Format](#提交信息格式--commit-message-format)
- [报告问题 / Reporting Issues](#报告问题--reporting-issues)
- [功能建议 / Feature Requests](#功能建议--feature-requests)
- [需要帮助的领域 / Areas Needing Help](#需要帮助的领域--areas-needing-help)

---

## 如何贡献 / How to Contribute

### 快速开始 / Quick Start

1. **Fork 仓库** / Fork the repository
   
   点击 GitHub 右上角的 "Fork" 按钮，将仓库复制到你的账户下。
   
   Click the "Fork" button in the top right of GitHub to copy the repository to your account.

2. **克隆你的 Fork** / Clone your fork
   
   ```bash
   git clone https://github.com/YOUR_USERNAME/Obsidian-OpenCode-Knowledge.git
   cd Obsidian-OpenCode-Knowledge
   ```

3. **创建分支** / Create a branch
   
   ```bash
   git checkout -b feat/your-feature-name
   # 或者 / or
   git checkout -b fix/bug-description
   ```

4. **进行修改** / Make your changes

5. **提交并推送** / Commit and push
   
   ```bash
   git add .
   git commit -m "feat: add new feature"
   git push origin feat/your-feature-name
   ```

6. **创建 Pull Request** / Create a Pull Request
   
   回到 GitHub，点击 "Compare & pull request"。
   
   Go back to GitHub and click "Compare & pull request".

---

## 开发环境搭建 / Development Setup

### 基本要求 / Basic Requirements

- **macOS** (主要支持平台 / primary supported platform)
- **Node.js** 18+ (用于运行某些工具 / for running certain tools)
- **Obsidian** (用于测试知识库模板 / for testing the knowledge base template)
- **OpenCode** (可选，用于体验完整工作流 / optional, for experiencing the full workflow)

### 快速测试 / Quick Testing

我们提供了 `setup.sh` 脚本来快速验证环境：

We provide a `setup.sh` script for quick environment verification:

```bash
# 克隆仓库 / Clone the repository
git clone https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge.git
cd Obsidian-OpenCode-Knowledge

# 运行测试脚本 / Run the test script
./setup.sh
```

这个脚本会检查：

- macOS 版本兼容性
- 必要的命令行工具
- 目录结构完整性

This script checks:

- macOS version compatibility
- Required command-line tools
- Directory structure integrity

---

## 代码规范 / Code Guidelines

### Bash 脚本 / Bash Scripts

所有 Bash 脚本遵循 **Google Shell Style Guide**：

All Bash scripts follow the **Google Shell Style Guide**:

- 使用 `#!/bin/bash` 或 `#!/usr/bin/env bash`
- 变量名使用小写字母和下划线：`local_var_name`
- 常量使用大写字母和下划线：`readonly CONSTANT_NAME`
- 函数名使用小写字母和下划线：`my_function_name()`
- 使用 `[[ ... ]]` 而不是 `[ ... ]` 进行条件测试
- 使用 `$()` 而不是反引号进行命令替换

```bash
#!/usr/bin/env bash

# 好的示例 / Good example
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_obsidian_path() {
    local vault_name="$1"
    echo "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/${vault_name}"
}

main() {
    local vault_path
    vault_path=$(get_obsidian_path "My Vault")
    
    if [[ -d "$vault_path" ]]; then
        echo "Found vault at: $vault_path"
    else
        echo "Vault not found" >&2
        return 1
    fi
}

main "$@"
```

### Markdown 文档 / Markdown Documents

- 使用 **Obsidian-flavored Markdown** 语法
- 文件命名使用描述性名称（不需要日期前缀）
- 内部链接使用相对路径：`[链接文本](./relative/path.md)`
- 代码块标注语言类型

```markdown
# 文章标题 / Article Title

正文内容在这里。Body content goes here.

## 章节 / Section

- 列表项 / List item
- 另一项 / Another item

[链接到其他文章](./other-article.md)
```

### 文件组织 / File Organization

```
.
├── raw/          # 原始素材（只读）/ Raw materials (read-only)
├── wiki/         # 知识库文章 / Knowledge base articles
├── assets/       # 图片和资源 / Images and resources
├── .github/      # GitHub 配置 / GitHub configuration
└── README.md     # 项目说明 / Project documentation
```

---

## 提交信息格式 / Commit Message Format

我们使用 **Conventional Commits** 规范，提交信息使用**英文**：

We use the **Conventional Commits** specification, with commit messages in **English**:

### 格式 / Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 类型 / Types

| 类型 / Type | 说明 / Description |
|------------|-------------------|
| `feat` | 新功能 / New feature |
| `fix` | 修复 Bug / Bug fix |
| `docs` | 文档更新 / Documentation changes |
| `style` | 代码格式（不影响功能）/ Code style (no functional change) |
| `refactor` | 代码重构 / Code refactoring |
| `perf` | 性能优化 / Performance improvement |
| `test` | 添加测试 / Adding tests |
| `chore` | 构建过程或辅助工具变动 / Build process or auxiliary tool changes |

### 示例 / Examples

```bash
# 新增功能 / New feature
feat(wiki): add article about async programming

# 修复问题 / Bug fix
fix(setup): handle spaces in vault path correctly

# 文档更新 / Documentation update
docs(readme): update installation instructions

# 代码重构 / Refactoring
refactor(scripts): extract common functions to lib.sh
```

---

## 报告问题 / Reporting Issues

发现了 Bug？请使用我们的 [Bug 报告模板](./.github/ISSUE_TEMPLATE/bug_report.md) 创建 Issue。

Found a bug? Please create an Issue using our [Bug Report Template](./.github/ISSUE_TEMPLATE/bug_report.md).

### 报告前请检查 / Before Reporting

- [ ] 搜索现有 Issue，确认问题未被报告过
- [ ] 尝试使用最新版本的代码复现问题
- [ ] 准备详细的复现步骤和环境信息

- [ ] Search existing Issues to ensure the problem hasn't been reported
- [ ] Try reproducing with the latest version
- [ ] Prepare detailed reproduction steps and environment info

---

## 功能建议 / Feature Requests

有新想法？请使用我们的 [功能建议模板](./.github/ISSUE_TEMPLATE/feature_request.md) 创建 Issue。

Have a new idea? Please create an Issue using our [Feature Request Template](./.github/ISSUE_TEMPLATE/feature_request.md).

---

## 需要帮助的领域 / Areas Needing Help

### 🌍 翻译 / Translations

- 将文档翻译成其他语言
- 改进现有翻译的准确性

- Translate documentation to other languages
- Improve accuracy of existing translations

### 🧩 新技能模板 / New Skill Templates

- 为特定工作流程创建 Skill 模板
- 分享你的 Obsidian + OpenCode 使用技巧

- Create Skill templates for specific workflows
- Share your Obsidian + OpenCode tips and tricks

### 🖥️ 跨平台支持 / Cross-Platform Support

- **Linux 支持**：适配 setup.sh 脚本
- **Windows 支持**：创建 PowerShell 版本的 setup 脚本

- **Linux support**: Adapt setup.sh script
- **Windows support**: Create PowerShell version of setup script

### 📝 文档改进 / Documentation Improvements

- 教程和指南
- 最佳实践案例
- FAQ 补充

- Tutorials and guides
- Best practice examples
- FAQ additions

### 🐛 测试 / Testing

- 在不同 macOS 版本上测试
- 测试与各种 Obsidian 插件的兼容性

- Test on different macOS versions
- Test compatibility with various Obsidian plugins

---

## 💬 联系方式 / Contact

- **GitHub Discussions**: 用于一般讨论和问答 / For general discussion and Q&A
- **GitHub Issues**: 用于 Bug 报告和功能请求 / For bug reports and feature requests

---

## 📜 行为准则 / Code of Conduct

- 友善对待每一位贡献者
- 尊重不同的观点和经验
- 专注于对社区最有利的事情

- Be friendly to every contributor
- Respect different perspectives and experiences
- Focus on what's best for the community

---

再次感谢你的贡献！/ Thank you again for your contribution!
