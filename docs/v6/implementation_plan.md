# 思维导图页面高保真原型优化 (v6.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove bookmark button, adjust layout switcher gap, and replicate the right sidebar's tabs, markdown icons, active styling, sibling navigation, and style color pickers based on screenshot specifications.

**Architecture:** Modify `D:/starmind/prototype/思维导图页面/index.html` to update layout positioning scripts, breadcrumbs elements, CSS style settings, and right sidebar layout markup, introducing dynamic sibling note cycling and style swatches.

**Tech Stack:** Vanilla HTML, CSS, SVG, JavaScript.

---

### Task 1: 顶部栏与面包屑路径重构

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 移除书签按钮并高亮收藏星星**
  
  修改面包屑操作栏中的“收藏”按钮，使星星在默认状态下为金黄色实心。同时确保已彻底移除书签按钮（或保留为删除注释）。
  
  定位 `index.html` 中的面包屑操作栏 `<div class="bb-left">` 区域，修改代码如下：
  ```html
  <div class="bb-left">
    <div class="bb-btn" title="后退"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></div>
    <div class="bb-btn" title="前进"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg></div>
    
    <!-- 收藏高亮为实心星星 -->
    <div class="bb-btn starred" title="收藏" style="color: #e0a92e;"><svg viewBox="0 0 24 24" fill="#e0a92e" stroke="#e0a92e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></polygon></svg></div>
    
    <!-- 注：书签按钮已按需移除 -->
    
    <!-- 面包屑路径前添加 Home 图标 -->
    <span class="bb-path" style="display: flex; align-items: center; gap: 4px;">
      <svg class="bb-path-home" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width: 14px; height: 14px; color: var(--ts);"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
      AI配音
    </span>
  </div>
  ```

- [ ] **Step 2: 验证收藏高亮与路径 Home 图标**
  
  打开原型网页，确认顶部左上操作栏只剩下后退、前进、金黄色星星以及 `🏠 AI配音` 路径。

---

### Task 2: 布局切换悬浮弹窗微调

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 缩小布局切换弹窗与底部工具栏的间隙**
  
  修改 layoutDropdown 在 JavaScript 中的垂直位置计算。将偏移量从 `- 8` 改为 `- 2`。同时利用 `offsetHeight || 98` 规避首次点击高度读取为 0 的异常。
  
  修改 `index.html` 中 `toggleLayoutMenu` 函数为：
  ```javascript
  function toggleLayoutMenu(e) {
    if (isLocked) return;
    e.stopPropagation();
    layoutDropdown.classList.toggle('show');
    if (layoutDropdown.classList.contains('show')) {
      const rect = document.getElementById('layoutBtn').getBoundingClientRect();
      layoutDropdown.style.display = 'block'; 
      layoutDropdown.style.left = (rect.left + rect.width / 2 - 50) + 'px';
      // 动态减去 offsetHeight 和 2px 空隙，保证不重叠并具有合适的小间隙
      layoutDropdown.style.top = (rect.top - (layoutDropdown.offsetHeight || 98) - 2) + 'px'; 
    } else {
      layoutDropdown.style.display = 'none';
    }
  }
  ```

- [ ] **Step 2: 验证布局切换菜单定位**
  
  点击底部布局切换按钮，确认弹窗精准在其正上方 2px 处浮出，间距紧凑而美观。

---

### Task 3: 右侧侧边栏标签页与图标重构

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 添加侧边栏垂直 Tab 激活样式**
  
  侧边栏右侧垂直标签页在激活状态时，应展现为 solid 深蓝色背景，且图标为纯白色。
  
  在 `<style>` 区添加或覆盖 `.rst-tab.active` 样式：
  ```css
  .rst-tab.active {
    background: #1862c6 !important;
    color: #ffffff !important;
    border: none !important;
    box-shadow: 0 2px 8px rgba(24, 98, 198, 0.4);
  }
  ```

- [ ] **Step 2: 更换侧边栏 Tab 与头部图标**
  
  1. 将“节点笔记”左侧的 `rsh-icon` 替换为纸飞机发送图标。
  2. 将 3rd Tab（主题）图标替换为 slanted 图钉（Pin）图标。
  3. 将 5th Tab（节点图标）图标更换为笑脸（Smiley Face）图标。
  
  修改 HTML 模板中对应节点：
  
  *“节点笔记” header 左侧 icon：*
  ```html
  <div class="rsh-left">
    <svg class="rsh-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width: 14px; height: 14px; margin-right: 6px;"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
    <span>节点笔记</span>
  </div>
  ```
  
  *3rd Tab（主题）垂直 Tab：*
  ```html
  <!-- 3. 主题 -->
  <div class="rst-tab" onclick="switchSidebarTab('theme')" title="导图主题">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4.5l-4 4L12 14l-5 5H4v-3l5-5L8 7.5l4-4z"/><path d="M9 15l-5 5"/></svg>
  </div>
  ```
  
  *5th Tab（节点图标）垂直 Tab：*
  ```html
  <!-- 5. 节点图标 -->
  <div class="rst-tab" onclick="switchSidebarTab('icon')" title="节点图标">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>
  </div>
  ```

- [ ] **Step 3: 验证 Tab 激活样式与图标呈现**
  
  确认侧边栏“节点笔记”标签（第一个）显示为高亮的圆角蓝色方块，内含白色的文档图标；“主题”图标显示为图钉，且“节点笔记”头部显示为纸飞机图标。

---

### Task 4: Markdown 编辑工具栏重构

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 重排并补全工具栏分割线与图标**
  
  根据截图完美重排两行工具栏，调整引用、代码块、行内代码与云上传等图标：
  
  将 `md-toolbar` 替换为以下代码：
  ```html
  <!-- Markdown Editor Toolbar -->
  <div class="md-toolbar">
    <div class="mdt-row">
      <button class="mdt-btn" title="标题" onclick="insertMarkdown('### ')">H</button>
      <button class="mdt-btn" title="加粗" onclick="insertMarkdown('**')">B</button>
      <button class="mdt-btn" title="斜体" onclick="insertMarkdown('*')">I</button>
      <button class="mdt-btn" title="删除线" style="text-decoration: line-through;" onclick="insertMarkdown('~~')">S</button>
      <button class="mdt-btn" title="链接" onclick="insertMarkdown('[]()')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
      </button>
      <span class="mdt-sep"></span>
      <button class="mdt-btn" title="无序列表" onclick="insertMarkdown('\n- ')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg></button>
      <button class="mdt-btn" title="有序列表" onclick="insertMarkdown('\n1. ')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 6h11M10 12h11M10 18h11M3 6h.01M3 12h.01M3 18h.01"/></svg></button>
      <button class="mdt-btn" title="任务列表" onclick="insertMarkdown('\n- [ ] ')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><polyline points="9 11 11 13 15 9"/></svg></button>
      <span class="mdt-sep"></span>
      <button class="mdt-btn" title="引用" onclick="insertMarkdown('\n> ')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
      </button>
      <button class="mdt-btn" title="分割线" onclick="insertMarkdown('\n---\n')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/></svg></button>
    </div>
    <div class="mdt-row">
      <button class="mdt-btn" title="代码块" onclick="insertMarkdown('\n```\n\n```')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/><line x1="14" y1="4" x2="10" y2="20"/></svg></button>
      <button class="mdt-btn" title="行内代码" onclick="insertMarkdown('`')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="8 6 2 12 8 18"/><polyline points="16 18 22 12 16 6"/></svg>
      </button>
      <span class="mdt-sep"></span>
      <button class="mdt-btn" title="上传附件" onclick="alert('触发文件上传附件操作...')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.2 15c.7-1.2 1-2.5.7-3.9-.5-2-2.4-3.5-4.4-3.5h-1.2C15.8 4.9 13.5 3 11 3 7.7 3 5 5.7 5 9c0 .4 0 .8.1 1.2C3.1 11 2 12.8 2 15c0 2.8 2.2 5 5 5h13c2.2 0 4-1.8 4-4 0-.4-.1-.8-.2-1.2z"/><polyline points="16 12 12 8 8 12"/><line x1="12" y1="8" x2="12" y2="16"/></svg>
      </button>
      <button class="mdt-btn" title="表格" onclick="insertMarkdown('\n| Header | Header |\n| ------ | ------ |\n| Cell   | Cell   |\n')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg></button>
      <span class="mdt-sep"></span>
      <button class="mdt-btn" title="撤销"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg></button>
      <button class="mdt-btn" title="重做"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg></button>
    </div>
  </div>
  ```

- [ ] **Step 2: 验证编辑器工具栏排列**
  
  运行页面，核对编辑器工具栏各个按钮的 SVG 图标形状与分割线排布，确保与设计图完美复刻。

---

### Task 5: 侧边栏兄弟节点笔记切换

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 实现兄弟节点导航交互逻辑**
  
  在 JS 部分增加 `navigateSibling(direction)` 切换兄弟节点笔记的逻辑。同时将该函数绑定至 header 中的“上一个” `<` 和“下一个” `>` 按钮。
  
  在 `<script>` 标签内添加：
  ```javascript
  function navigateSibling(direction) {
    const activeNode = document.querySelector('.tree-node.active');
    if (!activeNode) return;
    
    const currentBranch = activeNode.closest('.tree-branch');
    if (!currentBranch) return; // 根节点没有兄弟节点，直接返回
    
    const parentContainer = currentBranch.parentElement;
    if (!parentContainer) return;
    
    // 获取同级分支
    const siblings = Array.from(parentContainer.children).filter(el => el.classList.contains('tree-branch'));
    if (siblings.length <= 1) return;
    
    const siblingNodes = siblings.map(sb => sb.querySelector('.tree-node')).filter(n => n !== null);
    const currentIndex = siblingNodes.indexOf(activeNode);
    if (currentIndex === -1) return;
    
    let targetIndex;
    if (direction === 'prev') {
      targetIndex = (currentIndex - 1 + siblingNodes.length) % siblingNodes.length;
    } else {
      targetIndex = (currentIndex + 1) % siblingNodes.length;
    }
    
    selectNode(siblingNodes[targetIndex]);
  }
  ```
  
  绑定至 HTML 中的切换按钮：
  ```html
  <div class="rsh-btn" title="上一个" onclick="navigateSibling('prev')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"/></svg></div>
  <div class="rsh-btn" title="下一个" onclick="navigateSibling('next')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg></div>
  ```

- [ ] **Step 2: 验证兄弟切换逻辑**
  
  选中“千问”节点，点击“上一个” `<` 按钮，确认当前选中卡片自动切至“minimax”，且侧边栏同步加载 minimax 笔记；再次点击“下一个” `>` 按钮，切回“千问”。

---

### Task 6: 样式配置面板（画布背景与网格颜色）

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 新增色块选择器样式**
  
  在 CSS 区新增色块排列与取色器样式：
  ```css
  .setting-item.flex-col {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }
  .color-preset-row {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    margin-top: 4px;
  }
  .color-preset-circle {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    cursor: pointer;
    border: 1.5px solid rgba(255,255,255,0.15);
    transition: all 0.15s ease;
    box-sizing: border-box;
  }
  .color-preset-circle:hover {
    transform: scale(1.2);
    border-color: rgba(255,255,255,0.5);
  }
  .color-preset-circle.active {
    box-shadow: 0 0 0 2px var(--info);
    transform: scale(1.1);
  }
  .color-picker-wrapper {
    position: relative;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .color-picker-wrapper input[type="color"] {
    position: absolute;
    opacity: 0;
    width: 100%;
    height: 100%;
    cursor: pointer;
  }
  .color-picker-label {
    font-size: 14px;
    cursor: pointer;
    line-height: 1;
  }
  ```

- [ ] **Step 2: 改写样式标签页 HTML**
  
  定位并修改样式 Tab (`id="rs-content-style"`) 中的控制条，增加画布背景色及网格线颜色控制区：
  ```html
  <!-- Tab 4: 样式 Panel -->
  <div class="rs-content" id="rs-content-style" style="display:none;">
    <div class="rs-header">
      <div class="rsh-left">
        <svg class="rsh-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="2" y1="14" x2="6" y2="14"/><line x1="10" y1="8" x2="14" y2="8"/><line x1="18" y1="16" x2="22" y2="16"/></svg>
        <span>样式与配置</span>
      </div>
    </div>
    <div class="rs-body-pad" style="gap: 16px; display: flex; flex-direction: column;">
      <!-- 新增画布背景色 -->
      <div class="setting-item flex-col">
        <span class="setting-label">画布背景色</span>
        <div class="color-preset-row">
          <div class="color-preset-circle active" style="background: #0c0a07;" onclick="changeCanvasBg('#0c0a07', this)" title="经典漆黑"></div>
          <div class="color-preset-circle" style="background: #141b24;" onclick="changeCanvasBg('#141b24', this)" title="深空灰蓝"></div>
          <div class="color-preset-circle" style="background: #0a140d;" onclick="changeCanvasBg('#0a140d', this)" title="密林暗绿"></div>
          <div class="color-preset-circle" style="background: #0a0515;" onclick="changeCanvasBg('#0a0515', this)" title="紫幻魅影"></div>
          <div class="color-picker-wrapper">
            <input type="color" id="canvasBgPicker" onchange="changeCanvasBg(this.value, null)" value="#0c0a07">
            <label for="canvasBgPicker" class="color-picker-label" title="自定义背景色">🎨</label>
          </div>
        </div>
      </div>

      <!-- 新增网格线颜色 -->
      <div class="setting-item flex-col">
        <span class="setting-label">网格线颜色</span>
        <div class="color-preset-row">
          <div class="color-preset-circle active" style="background: rgba(255,255,255,0.02); border: 1.5px solid rgba(255,255,255,0.25);" onclick="changeGridColor('rgba(255, 255, 255, 0.02)', this)" title="微白"></div>
          <div class="color-preset-circle" style="background: rgba(250,210,120,0.05);" onclick="changeGridColor('rgba(250, 210, 120, 0.05)', this)" title="浅柔金"></div>
          <div class="color-preset-circle" style="background: rgba(0,240,255,0.03);" onclick="changeGridColor('rgba(0, 240, 255, 0.03)', this)" title="冰爽蓝"></div>
          <div class="color-preset-circle" style="background: rgba(255,0,127,0.03);" onclick="changeGridColor('rgba(255, 0, 127, 0.03)', this)" title="霓虹红"></div>
          <div class="color-picker-wrapper">
            <input type="color" id="gridColorPicker" onchange="changeGridColor(hexToRgba(this.value, 0.03), null)" value="#ffffff">
            <label for="gridColorPicker" class="color-picker-label" title="自定义网格色">🎨</label>
          </div>
        </div>
      </div>

      <div class="setting-item">
        <span class="setting-label">显示网格</span>
        <div class="setting-switch active" id="toggleGrid" onclick="toggleGridStyle()"></div>
      </div>
      <div class="setting-item">
        <span class="setting-label">彩虹分支颜色</span>
        <div class="setting-switch" id="toggleRainbow" onclick="toggleRainbowStyle()"></div>
      </div>
      <div class="setting-item">
        <span class="setting-label">导图线样式</span>
        <select class="style-select" id="lineStyleSelect" onchange="changeLineStyle()">
          <option value="bezier">贝塞尔曲线</option>
          <option value="straight">直线连接</option>
          <option value="ortho">直角连线</option>
        </select>
      </div>
      <div class="setting-item">
        <span class="setting-label">网格大小</span>
        <input type="range" class="style-range" min="15" max="30" value="20" oninput="changeGridSize(this.value)">
      </div>
    </div>
  </div>
  ```

- [ ] **Step 3: 添加背景与网格颜色控制脚本**
  
  在 JS 区中，改写与补充画布背景和网格颜色更新函数：
  ```javascript
  // 画布背景切换
  function changeCanvasBg(color, element) {
    document.documentElement.style.setProperty('--bg0', color);
    if (element) {
      const parent = element.parentElement;
      parent.querySelectorAll('.color-preset-circle').forEach(c => c.classList.remove('active'));
      element.classList.add('active');
    }
  }

  // 辅助十六进制转 RGBA
  function hexToRgba(hex, opacity) {
    let c;
    if(/^#([A-Fa-f0-9]{3}){1,2}$/.test(hex)){
      c= hex.substring(1).split('');
      if(c.length == 3){
        c= [c[0], c[0], c[1], c[1], c[2], c[2]];
      }
      c= '0x' + c.join('');
      return 'rgba('+[(c>>16)&255, (c>>8)&255, c&255].join(',')+','+opacity+')';
    }
    return 'rgba(255,255,255,0.02)';
  }

  // 网格线颜色切换
  let currentGridColor = 'rgba(255, 255, 255, 0.02)';
  function changeGridColor(color, element) {
    currentGridColor = color;
    updateGridBackground();
    if (element) {
      const parent = element.parentElement;
      parent.querySelectorAll('.color-preset-circle').forEach(c => c.classList.remove('active'));
      element.classList.add('active');
    }
  }

  function updateGridBackground() {
    const sw = document.getElementById('toggleGrid');
    if (sw.classList.contains('active')) {
      workspace.style.backgroundImage = `
        linear-gradient(${currentGridColor} 1px, transparent 1px),
        linear-gradient(90deg, ${currentGridColor} 1px, transparent 1px)
      `;
    } else {
      workspace.style.backgroundImage = 'none';
    }
  }

  // 保证与网格开关同步
  function toggleGridStyle() {
    const sw = document.getElementById('toggleGrid');
    sw.classList.toggle('active');
    updateGridBackground();
  }
  ```

- [ ] **Step 4: 验证样式与背景交互**
  
  切换侧边栏到“样式与配置”（第4个），点击“深空灰蓝”，确认画布背景变为深蓝色；点击“浅柔金”网格颜色，确认网格线变成金色细线；滑动网格大小，确认粗细大小平滑过渡。
