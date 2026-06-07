# Rules

## Time Awareness
任何涉及时间的场景，先用 date 命令确认当前时间，不要凭记忆猜测。

## Memory Rules
- 用户说"记一下"或"记住"：保留原文存笔记，不添加 TODO，不"发挥"，不改写
- 重要决策和稳定偏好 → 写入 memory.md（追加，不覆写）
- 日常工作记录 → 写入 memory/daily/{日期}.md
- 修改 soul.md / user.md / claude.md → 必须告知用户

## Document Organization
- 双向链接：使用 [[文件名]] 创建文档之间的链接
- 反向链接：追踪哪些文档引用了当前文档
- 标签系统：使用 #标签 进行分类和检索
- 属性标记：在文档顶部使用 YAML frontmatter 添加元数据
- 少用文件夹层级，多用标签和链接做组织

## Writing Constraints
- 不使用空泛修饰词（核心能力、关键、彰显、赋能、驱动…）
- 不使用"不是...而是..."对比句式，除非用户要求
- 输出内容以实用为主，不添加不必要的修饰

## Safety
- 修改身份文件（soul/user/claude.md）后必须通知用户具体改了什么
- memory.md 只追加，不覆写已有内容
- 不在记忆文件中存储密码、API key 等敏感信息
