---
# ============================================================
# AI 知识库配置
# 编辑此文件可自定义 AI 行为。修改后下次对话自动生效。
# ============================================================

# 输出语言：zh（中文）/ en（英文）
language: zh

# 触发词 — 用户说出这些话时 AI 执行对应操作
triggers:
  ingest: ["加到 wiki", "ingest 这个", "把这个收进来", "记录下来", "保存这个"]
  query: ["我知道啥关于", "wiki 里有没有", "总结一下", "查一下"]
  lint: ["lint wiki", "体检", "wiki 有啥问题"]
  social_ingest: ["爬了这个", "收录这条", "这条收进来"]

# 知识域分类（按内容主题，不按平台）
# 可自由增删。AI 会根据 description 判断分类。
domains:
  - name: 消费研究
    description: 探店、测评、好物推荐、价格对比
  - name: 技能方法
    description: 教程、攻略、方法论、经验分享
  - name: 行业洞察
    description: 趋势分析、商业观察、行业报告
  - name: 生活方式
    description: 旅行、美食、穿搭、家居、健康
  - name: 观点思考
    description: 深度评论、思考、价值观输出
  - name: 创意灵感
    description: 设计、文案、营销案例、内容创作
  - name: 资源收藏
    description: 工具推荐、书单、课程、资源清单

# 支持的社交平台
# 可自由增删。新增平台时图片路径自动适配。
platforms:
  - Xiaohongshu
  - Douyin
  - Twitter
  - Weibo
  - Bilibili
  - WeChat

# 内容类型（影响消化处理策略）
content_types:
  - 实测体验
  - 教程攻略
  - 分析评论
  - 资源清单
  - 个人观点

# 润色规则
polish:
  strip_patterns: ["绝绝子", "yyds", "安利", "种草", "宝藏"]
  keep_subjective: true
  output_language: zh

# Lint 体检检查项
# true = 启用（确定性检查会自动修，启发式检查只报告）
# false = 跳过
lint_checks:
  index_consistency: true
  broken_links: true
  see_also_links: true
  fact_contradiction: false
  orphaned_pages: false
  missing_cross_refs: false

# Frontmatter 字段定义
# required = 必须包含的字段
# optional = 可选字段
frontmatter:
  required: [title, source, author, created, domain]
  optional: [note_url, content_type, credibility, metrics, tags]
---

# AI 知识库配置

> 编辑此文件上方的配置区域即可自定义 AI 行为。修改后下次对话自动生效。

## 常见自定义

### 添加新知识域

在 `domains` 列表中添加新条目：

```yaml
- name: 学术笔记
  description: 论文摘要、学术观点、研究方法
```

### 添加新平台

在 `platforms` 列表中添加平台名，如 `Zhihu`、`Instagram`、`Reddit`。

### 修改输出语言

将 `language` 和 `polish.output_language` 都改为 `en`，AI 会用英文消化内容。

### 调整触发词

在 `triggers` 对应列表中增删关键词。触发词是模糊匹配的，不需要精确。

### 关闭某些检查

在 `lint_checks` 中将不需要的检查项设为 `false`。

### 自定义规则

在下方 `user-custom-rules` 之间写你的额外规则，AI 会读取并遵循：

<!-- user-custom-rules-start -->

<!-- 在这里写你的自定义规则。例如： -->
<!-- - 所有笔记必须包含 Summary 段落 -->
<!-- - 消费研究类笔记必须包含价格区间 -->
<!-- - 跳过 credibility 为 low 的素材 -->
<!-- - wiki 文章末尾必须列出 Sources -->

<!-- user-custom-rules-end -->
