# 思维导图页面高保真原型实现计划 (v5.0)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个与 `首页` 和 `pdf批注页面` 风格一致的高保真思维导图交互原型，文件保存在 `D:/starmind/prototype/思维导图页面/index.html`。

**Architecture:** 采用嵌套 DOM 容器实现脑图层次结构，结合底层绝对定位的全屏 SVG 动态绘制贝塞尔曲线连接线。通过原生 JS 实现平移缩放、节点展开折叠、激活状态高亮及工具栏微交互。

**Tech Stack:** HTML5, CSS3, Vanilla JavaScript, SVG.

---

## Proposed Changes

### 原型页面

#### [NEW] [index.html](file:///D:/starmind/prototype/思维导图页面/index.html)
新建思维导图原型的全部代码，包含 HTML、CSS 样式和 JavaScript 交互逻辑。

---

## User Review Required

> [!NOTE]
> 本原型为前端高保真静态原型，包含丰富的动态交互（展开/折叠、选中、缩放、平移、工具栏微动效），但不包含后端数据库存储。

---

## Verification Plan

### Manual Verification
1. 用浏览器打开 `D:/starmind/prototype/思维导图页面/index.html`。
2. 确认背景网格、背景发光光圈、顶部标签栏、顶部路径栏、左侧缩放条和底部工具栏渲染正确。
3. 点击“常用平台”和“分支主题3”节点，验证子分支能否正常收起/展开，且连接线能平滑重绘。
4. 点击左下角缩放按钮 `+`/`-`，验证脑图是否整体缩放；拖拽背景，验证脑图是否可以平滑移动。
5. 点击任意节点，确认金色高亮框（`--accent`）正确出现。

---

## Implementation Tasks

### Task 1: 基础骨架与顶部 Tab 栏

**Files:**
- Create: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 创建 HTML 骨架及全局 CSS 变量定义**
  写入基础 HTML 模板，引入字体，并定义与已有原型完全一致的配色变量。
  ```html
  <!DOCTYPE html>
  <html lang="zh-CN">
  <head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>StarMind — AI配音思维导图</title>
  <style>
  *{margin:0;padding:0;box-sizing:border-box;}
  :root{
    --bg0:#0c0a07;--bg1:#141008;--bg2:#1c1710;
    --glass:rgba(255,248,230,0.055);
    --glass-h:rgba(255,248,230,0.1);
    --glass-a:rgba(255,248,230,0.14);
    --border:rgba(255,220,140,0.08);
    --border-h:rgba(255,220,140,0.18);
    --accent:#c8841a;--accent2:#e8a83c;
    --accent-glow:rgba(200,132,26,0.35);
    --accent-bg:rgba(200,132,26,0.15);
    --tp:rgba(255,248,235,0.9);
    --ts:rgba(255,248,235,0.52);
    --tm:rgba(255,248,235,0.28);
    --danger:#e05858;
    --success:#5ce8a0;
    --info:#5cb8fc;
  }
  body{
    font-family:-apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif;
    background:var(--bg0);color:var(--tp);
    height:100vh;overflow:hidden;user-select:none;
  }
  .orb{position:fixed;border-radius:50%;filter:blur(100px);pointer-events:none;z-index:0;}
  .o1{width:500px;height:500px;background:#6b3a08;opacity:.12;top:-150px;left:-100px;}
  .o2{width:360px;height:360px;background:#3d1f02;opacity:.15;bottom:-80px;right:-60px;}
  .o3{width:280px;height:280px;background:#1a2820;opacity:.1;top:35%;left:42%;}
  </style>
  </head>
  <body>
  <div class="orb o1"></div>
  <div class="orb o2"></div>
  <div class="orb o3"></div>
  </body>
  </html>
  ```

- [ ] **Step 2: 构建顶部标签栏 (Tab Bar)**
  在 body 中加入 Tab Bar 的 HTML 结构，定义样式，展示三个 Tabs（首页、数学高数、AI配音为激活态），并包含分屏、置顶与设置按钮。
  ```html
  <!-- 在 body 中添加 -->
  <div class="app">
    <div class="tab-bar">
      <div class="tab-tabs">
        <div class="tab-it">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>
          首页
        </div>
        <div class="tab-it">
          <svg class="pdf-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          2026考研数学高数-姜…
        </div>
        <div class="tab-it active">
          <!-- 脑图小图标 -->
          <svg class="map-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><circle cx="5" cy="6" r="2"/><circle cx="19" cy="6" r="2"/><circle cx="5" cy="18" r="2"/><circle cx="19" cy="18" r="2"/><line x1="9.5" y1="10" x2="6.5" y2="7.5"/><line x1="14.5" y1="10" x2="17.5" y2="7.5"/><line x1="9.5" y1="14" x2="6.5" y2="16.5"/><line x1="14.5" y1="14" x2="17.5" y2="16.5"/></svg>
          AI配音
          <div class="tab-x"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></div>
        </div>
      </div>
      <div class="win-ctrls">
        <div class="wc"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="12" y1="3" x2="12" y2="21"/></svg></div>
        <div class="wc"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg></div>
        <div class="wc"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg></div>
      </div>
    </div>
  </div>
  ```

---

### Task 2: 顶部操作路径栏与面包屑

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 构建操作路径栏 (Breadcrumb Bar)**
  在 HTML 中添加操作路径栏的结构，并完成相关的 CSS 布局。
  ```html
  <!-- 在 app 容器中，紧随 tab-bar 之后添加 -->
  <div class="breadcrumb-bar">
    <div class="bb-left">
      <div class="bb-btn" title="后退"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></div>
      <div class="bb-btn" title="前进"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg></div>
      <div class="bb-btn" title="收藏"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg></div>
      <div class="bb-btn" title="书签"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg></div>
      <div class="bb-btn" title="首页"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg></div>
      <span class="bb-path">AI配音</span>
    </div>
    <div class="bb-right">
      <div class="bb-btn" title="撤销"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg></div>
      <div class="bb-btn" title="重做"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg></div>
      <div class="bb-btn" title="布局树状图"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 3H7a4 4 0 0 0-4 4v10a4 4 0 0 0 4 4h10a4 4 0 0 0 4-4V7a4 4 0 0 0-4-4z"/><circle cx="12" cy="12" r="3"/></svg></div>
      <div class="bb-btn" title="更多"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="1"/><circle cx="12" cy="5" r="1"/><circle cx="12" cy="19" r="1"/></svg></div>
      <div class="bb-btn" title="侧栏"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="3" x2="9" y2="21"/></svg></div>
    </div>
  </div>
  ```

---

### Task 3: 画布区域设置与背景网格

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 添加脑图画布容器与背景 CSS 样式**
  在 breadcrumb-bar 后添加 workspace 容器。样式使用 CSS `linear-gradient` 创建微网格，并且将背景发光光圈 `.orb` 置于此背景下层。
  ```html
  <div class="workspace" id="workspace">
    <!-- SVG 贝塞尔连接线画布 -->
    <svg class="connectors-svg" id="connectorsSvg"></svg>
    <!-- 可平移缩放的内容画布 -->
    <div class="canvas-content" id="canvasContent">
      <!-- 脑图树节点内容在此加载 -->
    </div>
  </div>
  ```
  在 CSS 中加入：
  ```css
  .workspace {
    flex: 1;
    position: relative;
    overflow: hidden;
    background-color: var(--bg0);
    background-image: 
      linear-gradient(rgba(255, 220, 140, 0.015) 1px, transparent 1px),
      linear-gradient(90deg, rgba(255, 220, 140, 0.015) 1px, transparent 1px);
    background-size: 24px 24px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .connectors-svg {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 1;
  }
  .canvas-content {
    position: absolute;
    display: flex;
    align-items: center;
    transform-origin: center center;
    z-index: 2;
    padding: 100px;
    cursor: grab;
    transition: transform 0.05s ease-out;
  }
  .canvas-content:active {
    cursor: grabbing;
  }
  ```

---

### Task 4: 脑图节点 HTML 结构与 CSS

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 构建脑图静态嵌套结构 (DOM Node Tree)**
  用 `flex` 容器配合 `row` 布局构建对称的层级节点关系。每个子分支有独立的子列。
  ```html
  <!-- 在 canvasContent 内部添加 -->
  <div class="mind-tree">
    <!-- 根节点 -->
    <div class="mind-node root-node" id="node-root" onclick="selectNode(this)">
      AI配音
    </div>
    
    <!-- 子分支容器 -->
    <div class="mind-branches">
      
      <!-- 分支1：常用平台 -->
      <div class="mind-branch-group" id="group-branch1">
        <div class="branch-connector-point">
          <div class="mind-node branch-node-l1 red-node" id="node-branch1" onclick="selectNode(this)">
            常用平台
            <div class="toggle-btn" onclick="toggleBranch(event, 'branch1')"></div>
          </div>
        </div>
        
        <div class="mind-sub-branches" id="sub-branch1">
          <!-- 国内平台 -->
          <div class="mind-branch-group" id="group-branch1-1">
            <div class="branch-connector-point">
              <div class="mind-node branch-node-l2 dark-node" id="node-branch1-1" onclick="selectNode(this)">
                国内平台
                <div class="toggle-btn" onclick="toggleBranch(event, 'branch1-1')"></div>
              </div>
            </div>
            
            <div class="mind-sub-branches" id="sub-branch1-1">
              <div class="mind-node leaf-node dark-node" id="node-leaf1" onclick="selectNode(this)">minimax</div>
              <div class="mind-node leaf-node dark-node" id="node-leaf2" onclick="selectNode(this)">千问</div>
              <div class="mind-node leaf-node dark-node" id="node-leaf3" onclick="selectNode(this)">豆包</div>
            </div>
          </div>
          
          <!-- 国外平台 -->
          <div class="mind-node leaf-node dark-node" id="node-branch1-2" onclick="selectNode(this)">国外平台</div>
        </div>
      </div>
      
      <!-- 分支2：分支主题3 -->
      <div class="mind-branch-group" id="group-branch2">
        <div class="branch-connector-point">
          <div class="mind-node branch-node-l1 purple-node" id="node-branch2" onclick="selectNode(this)">
            <svg class="flag-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M14.4 6L14 4H5v17h2v-7h5.6l.4 2h7V6z"/></svg>
            分支主题3
            <div class="toggle-btn" onclick="toggleBranch(event, 'branch2')"></div>
          </div>
        </div>
        
        <div class="mind-sub-branches" id="sub-branch2">
          <div class="mind-node leaf-node dark-node" id="node-leaf4" onclick="selectNode(this)">小说</div>
        </div>
      </div>
      
    </div>
  </div>
  ```

- [ ] **Step 2: 添加节点排版及色彩 CSS 样式**
  定义树型网格的 CSS，以及各种类型节点的卡片圆角、内边距、发光边框等。
  ```css
  .mind-tree {
    display: flex;
    align-items: center;
    gap: 60px;
  }
  .mind-branches {
    display: flex;
    flex-direction: column;
    gap: 40px;
    position: relative;
  }
  .mind-branch-group {
    display: flex;
    align-items: center;
    gap: 60px;
  }
  .mind-sub-branches {
    display: flex;
    flex-direction: column;
    gap: 16px;
    position: relative;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .mind-node {
    padding: 12px 24px;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    text-align: center;
    cursor: pointer;
    position: relative;
    border: 1px solid transparent;
    transition: all 0.2s ease;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    white-space: nowrap;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .root-node {
    background-color: #272f3d;
    border-color: rgba(255,220,140,0.15);
    font-size: 18px;
    font-weight: 700;
    padding: 16px 32px;
    border-radius: 10px;
  }
  .red-node {
    background-color: #e05858;
    color: #fff;
  }
  .purple-node {
    background-color: #7b61ff;
    color: #fff;
  }
  .dark-node {
    background-color: #000;
    color: var(--tp);
    border-color: var(--border);
  }
  .mind-node:hover {
    transform: translateY(-2px);
    border-color: var(--border-h);
    box-shadow: 0 6px 16px rgba(0,0,0,0.5);
  }
  .mind-node.active {
    border-color: var(--accent) !important;
    box-shadow: 0 0 14px var(--accent-glow) !important;
  }
  .flag-icon {
    width: 14px;
    height: 14px;
    color: #f1c40f;
  }
  ```

---

### Task 5: 贝塞尔连接线渲染逻辑

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 编写连接线计算与 SVG 重绘脚本**
  使用贝塞尔曲线连接父子节点。
  ```html
  <!-- 在 body 结束前加入 script -->
  <script>
  const svg = document.getElementById('connectorsSvg');
  
  function drawBezierLine(parent, child, color = 'rgba(255,220,140,0.25)') {
    const parentRect = parent.getBoundingClientRect();
    const childRect = child.getBoundingClientRect();
    const svgRect = svg.getBoundingClientRect();
    
    // 计算父节点右边中点，子节点左边中点，并映射到 SVG 坐标系
    const sx = parentRect.left + parentRect.width - svgRect.left;
    const sy = parentRect.top + (parentRect.height / 2) - svgRect.top;
    const tx = childRect.left - svgRect.left;
    const ty = childRect.top + (childRect.height / 2) - svgRect.top;
    
    const dx = (tx - sx) * 0.45;
    
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', `M ${sx} ${sy} C ${sx + dx} ${sy}, ${tx - dx} ${ty}, ${tx} ${ty}`);
    path.setAttribute('fill', 'none');
    path.setAttribute('stroke', color);
    path.setAttribute('stroke-width', '2.5');
    svg.appendChild(path);
  }
  
  function updateConnectors() {
    svg.innerHTML = '';
    
    // 如果子分支可见，则绘制线段
    const root = document.getElementById('node-root');
    
    // 根 -> 常用平台
    const branch1 = document.getElementById('node-branch1');
    if (branch1 && isVisible(branch1)) {
      drawBezierLine(root, branch1, '#e05858');
      
      // 常用平台 -> 国内平台
      const branch1_1 = document.getElementById('node-branch1-1');
      if (branch1_1 && isVisible(branch1_1)) {
        drawBezierLine(branch1, branch1_1, '#e05858');
        
        // 国内平台子级
        ['leaf1', 'leaf2', 'leaf3'].forEach(id => {
          const leaf = document.getElementById('node-' + id);
          if (leaf && isVisible(leaf)) {
            drawBezierLine(branch1_1, leaf, '#e05858');
          }
        });
      }
      
      // 常用平台 -> 国外平台
      const branch1_2 = document.getElementById('node-branch1-2');
      if (branch1_2 && isVisible(branch1_2)) {
        drawBezierLine(branch1, branch1_2, '#e05858');
      }
    }
    
    // 根 -> 分支主题3
    const branch2 = document.getElementById('node-branch2');
    if (branch2 && isVisible(branch2)) {
      drawBezierLine(root, branch2, '#7b61ff');
      
      // 分支主题3 -> 小说
      const leaf4 = document.getElementById('node-leaf4');
      if (leaf4 && isVisible(leaf4)) {
        drawBezierLine(branch2, leaf4, '#7b61ff');
      }
    }
  }
  
  function isVisible(el) {
    return el.offsetWidth > 0 && el.offsetHeight > 0;
  }
  
  window.addEventListener('resize', updateConnectors);
  // 定时与重绘初始化
  setTimeout(updateConnectors, 100);
  </script>
  ```

---

### Task 6: 交互功能与浮动工具栏

**Files:**
- Modify: `D:/starmind/prototype/思维导图页面/index.html`

- [ ] **Step 1: 添加左侧与底部浮动控制栏 HTML 及 CSS**
  在主 workspace 内添加浮动面板的 HTML 结构与磨砂玻璃 CSS 样式。
  ```html
  <!-- 在 workspace 容器内部，紧随 canvasContent 之后添加 -->
  <!-- 左侧浮动缩放条 -->
  <div class="floating-zoom">
    <div class="fz-btn" onclick="zoomIn()">+</div>
    <div class="fz-val" id="zoomVal" onclick="zoomReset()">100%</div>
    <div class="fz-btn" onclick="zoomOut()">-</div>
    <div class="fz-sep"></div>
    <div class="fz-btn" title="信息"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg></div>
    <div class="fz-btn" title="帮助"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9.09 9a3 3 0 0 1 5.83 1C14.85 12 13 13 13 13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg></div>
    <div class="fz-btn" title="脑图模式"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path></svg></div>
  </div>
  
  <!-- 底部浮动操作条 -->
  <div class="floating-toolbar">
    <div class="ft-btn active" title="选择"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="3 3 10.07 19.97 12.58 11.58 20.97 9.07 3 3"/></svg></div>
    <div class="ft-btn" title="评论"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg></div>
    <div class="ft-btn" title="新建同级节点"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg></div>
    <div class="ft-btn" title="新建子级节点"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><circle cx="5" cy="6" r="2"/><circle cx="19" cy="6" r="2"/><line x1="9.5" y1="10" x2="6.5" y2="7.5"/><line x1="14.5" y1="10" x2="17.5" y2="7.5"/></svg></div>
    <div class="ft-btn" title="概要"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="9" x2="15" y2="9"/><line x1="9" y1="13" x2="15" y2="13"/><line x1="9" y1="17" x2="13" y2="17"/></svg></div>
    <div class="ft-btn" title="框选"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" stroke-dasharray="4 4"/></svg></div>
    <div class="ft-btn" title="关联"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg></div>
    <div class="ft-btn" title="标签"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg></div>
    <div class="ft-btn" title="语音"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/></svg></div>
    <div class="ft-btn" title="文档"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div>
    <div class="ft-btn" title="锁定"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg></div>
  </div>
  ```

- [ ] **Step 2: 编写折叠展开、缩放与节点选中 JS 逻辑**
  实现平移缩放、节点选中与分支折叠控制，折叠动作会动态给对应子级分支容器加 `.collapsed` 类。
  在 CSS 中加入：
  ```css
  .collapsed {
    display: none !important;
  }
  .toggle-btn {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background-color: var(--bg2);
    border: 1.5px solid var(--accent);
    position: absolute;
    right: -7px;
    top: 50%;
    transform: translateY(-50%);
    cursor: pointer;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .toggle-btn::after {
    content: '-';
    font-size: 10px;
    color: var(--accent);
    line-height: 1;
  }
  .mind-node.collapsed-state .toggle-btn::after {
    content: '+';
  }
  ```
  在 script 中写入：
  ```javascript
  // 节点折叠与展开
  function toggleBranch(event, branchId) {
    event.stopPropagation();
    const btn = event.currentTarget;
    const node = btn.closest('.mind-node');
    const subBranch = document.getElementById('sub-' + branchId);
    
    if (subBranch) {
      subBranch.classList.toggle('collapsed');
      node.classList.toggle('collapsed-state');
      setTimeout(updateConnectors, 50); // 重绘连接线
    }
  }
  
  // 选中节点
  function selectNode(el) {
    document.querySelectorAll('.mind-node').forEach(n => n.classList.remove('active'));
    el.classList.add('active');
  }
  
  // 画布缩放控制
  let currentScale = 1.0;
  const canvasContent = document.getElementById('canvasContent');
  const zoomVal = document.getElementById('zoomVal');
  
  function updateZoom() {
    canvasContent.style.transform = `translate(${panX}px, ${panY}px) scale(${currentScale})`;
    zoomVal.textContent = Math.round(currentScale * 100) + '%';
    updateConnectors();
  }
  
  function zoomIn() {
    if (currentScale < 2.0) {
      currentScale = parseFloat((currentScale + 0.1).toFixed(2));
      updateZoom();
    }
  }
  
  function zoomOut() {
    if (currentScale > 0.5) {
      currentScale = parseFloat((currentScale - 0.1).toFixed(2));
      updateZoom();
    }
  }
  
  function zoomReset() {
    currentScale = 1.0;
    updateZoom();
  }
  
  // 画布鼠标拖拽平移
  let isDragging = false;
  let startX, startY;
  let panX = 0, panY = 0;
  const workspace = document.getElementById('workspace');
  
  workspace.addEventListener('mousedown', (e) => {
    if (e.target.closest('.mind-node') || e.target.closest('.floating-zoom') || e.target.closest('.floating-toolbar')) {
      return;
    }
    isDragging = true;
    startX = e.clientX - panX;
    startY = e.clientY - panY;
    workspace.style.cursor = 'grabbing';
  });
  
  window.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    panX = e.clientX - startX;
    panY = e.clientY - startY;
    updateZoom();
  });
  
  window.addEventListener('mouseup', () => {
    isDragging = false;
    workspace.style.cursor = 'default';
  });
  ```
