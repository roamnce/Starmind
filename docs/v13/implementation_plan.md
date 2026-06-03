# 思维导图卡片布局复刻 (v13) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 复刻两个独立的思维导图框架卡片布局（亮色和暗色模式），达到完美的高保真视觉效果，并支持动态 SVG 贝塞尔曲线连线与基本的折叠/展开、高亮交互。

**Architecture:** 采用独立 HTML 页面形式，利用 HTML5/CSS3 (Flexbox/Grid, 自定义网格线) 进行核心结构排版，利用绝对定位的 SVG 作为背景画布渲染连接线，利用 Vanilla JS 动态计算节点坐标并绘制高精度的贝塞尔曲线。

**Tech Stack:** HTML5, CSS3, ES6 JavaScript, SVG.

---

### Task 1: 亮色思维导图框架卡片布局复刻

**Files:**
- Create: `d:/starmind/prototype/card_layout_light.html`

- [ ] **Step 1: 创建 HTML 基础框架**
  编写包含基本 DOM 结构的 HTML 文件。定义大框架、顶部标题栏、第一分支（包含一个父卡片和三个彩色子卡片）、第二分支（大嵌套卡片及其包含的两个子卡片）和定位用的 SVG 容器。
  
  ```html
  <!DOCTYPE html>
  <html lang="zh-CN">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>亮色卡片布局复刻</title>
    <style>
      /* 核心样式将在 Step 2 中引入 */
    </style>
  </head>
  <body>
    <div class="viewport">
      <div class="canvas">
        <svg class="connector-canvas" id="connectorSvg"></svg>
        
        <div class="main-card" id="mainCard">
          <!-- 标题栏 -->
          <div class="card-header">时间</div>
          
          <div class="card-body">
            <!-- 分支 1 (父->子) -->
            <div class="section-branch">
              <div class="parent-wrapper">
                <div class="node-card node-parent" id="nodeParent">
                  <div class="node-content">卡片</div>
                  <div class="anchor-out" id="parentOut"></div>
                </div>
              </div>
              
              <div class="children-column">
                <div class="node-card node-child child-teal" id="childTeal">
                  <div class="anchor-in"></div>
                  <div class="card-text">卡片</div>
                  <div class="card-divider"></div>
                  <div class="card-text">&nbsp;</div>
                </div>
                <div class="node-card node-child child-green" id="childGreen">
                  <div class="anchor-in"></div>
                  <div class="card-text">卡片</div>
                  <div class="card-divider"></div>
                  <div class="card-text">&nbsp;</div>
                </div>
                <div class="node-card node-child child-orange" id="childOrange">
                  <div class="anchor-in"></div>
                  <div class="card-text">卡片</div>
                  <div class="card-divider"></div>
                  <div class="card-text">&nbsp;</div>
                </div>
              </div>
            </div>
            
            <!-- 分支 2 (嵌套大卡片) -->
            <div class="section-nested">
              <div class="nested-container">
                <div class="nested-header">卡片</div>
                <div class="nested-body">
                  <div class="nested-card">
                    <div class="card-text">卡片</div>
                    <div class="card-divider"></div>
                    <div class="card-text">&nbsp;</div>
                  </div>
                  <div class="nested-card">
                    <div class="card-text">卡片</div>
                    <div class="card-divider"></div>
                    <div class="card-text">&nbsp;</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
      </div>
    </div>
    
    <script>
      // 动态计算连线将在 Step 3 中引入
    </script>
  </body>
  </html>
  ```

- [ ] **Step 2: 写入高保真 CSS 样式**
  使用 Vanilla CSS 构建美化层，包含 HSL 柔和配色方案、精致的圆角、虚线分隔符、卡片微阴影和 Hover 位移特效。
  
  ```css
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    background-color: #f4f7f6;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    overflow: hidden;
  }
  .viewport {
    position: relative;
    width: 100vw;
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    background: #f8fafc;
  }
  .canvas {
    position: relative;
    padding: 100px;
  }
  .connector-canvas {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 1;
  }
  .main-card {
    position: relative;
    z-index: 2;
    background: #ffffff;
    border: 1.5px solid #a7d6f5;
    border-radius: 12px;
    width: 480px;
    box-shadow: 0 10px 30px rgba(167, 214, 245, 0.18);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }
  .card-header {
    background-color: #bfe2fa;
    padding: 10px 16px;
    font-size: 13px;
    font-weight: bold;
    color: #1b4b72;
    border-bottom: 1.5px dashed #a7d6f5;
  }
  .card-body {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 28px;
  }
  .section-branch {
    display: flex;
    align-items: center;
    gap: 50px;
    position: relative;
  }
  .parent-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .node-card {
    border-radius: 8px;
    position: relative;
    transition: all 0.2s ease;
    cursor: pointer;
  }
  .node-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(0,0,0,0.06);
  }
  .node-parent {
    background: #ffffff;
    border: 1px solid #cce0f0;
    padding: 8px 20px;
    font-size: 12.5px;
    color: #4a5568;
    box-shadow: 0 2px 6px rgba(0,0,0,0.02);
  }
  .anchor-out {
    position: absolute;
    right: 0;
    top: 50%;
    transform: translate(50%, -50%);
    width: 6px;
    height: 6px;
    background: #a7d6f5;
    border-radius: 50%;
  }
  .children-column {
    display: flex;
    flex-direction: column;
    gap: 12px;
    flex: 1;
  }
  .node-child {
    width: 100%;
    padding: 10px 16px;
    display: flex;
    flex-direction: column;
    font-size: 12px;
  }
  .anchor-in {
    position: absolute;
    left: 0;
    top: 50%;
    transform: translate(-50%, -50%);
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }
  .child-teal {
    background-color: #9ad3df;
    border: 1px solid #74b9c7;
    color: #1e4650;
  }
  .child-teal .anchor-in { background-color: #74b9c7; }
  .child-teal .card-divider { border-bottom: 1px dashed rgba(30,70,80,0.25); }

  .child-green {
    background-color: #cfead4;
    border: 1px solid #a2d3ab;
    color: #234e2c;
  }
  .child-green .anchor-in { background-color: #a2d3ab; }
  .child-green .card-divider { border-bottom: 1px dashed rgba(35,78,44,0.25); }

  .child-orange {
    background-color: #fde3c3;
    border: 1px solid #e9be8a;
    color: #5d3f1a;
  }
  .child-orange .anchor-in { background-color: #e9be8a; }
  .child-orange .card-divider { border-bottom: 1px dashed rgba(93,63,26,0.25); }

  .card-divider {
    width: 100%;
    margin: 6px 0;
  }
  .card-text {
    min-height: 14px;
    font-weight: 500;
  }
  .section-nested {
    width: 100%;
  }
  .nested-container {
    background: #f8fafc;
    border: 1.5px solid #e2e8f0;
    border-radius: 10px;
    padding: 14px;
  }
  .nested-header {
    font-size: 12.5px;
    font-weight: bold;
    color: #64748b;
    margin-bottom: 10px;
  }
  .nested-body {
    display: flex;
    gap: 12px;
  }
  .nested-card {
    flex: 1;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    padding: 10px;
    font-size: 11px;
    color: #475569;
  }
  .nested-card .card-divider {
    border-bottom: 1px dashed #e2e8f0;
  }
  ```

- [ ] **Step 3: 写入 Vanilla JS 动态贝塞尔曲线计算**
  计算 `.node-parent` 与各个子卡片的相对坐标差，绘制动态连线，并支持窗口缩放时自适应重画。
  
  ```javascript
  const svg = document.getElementById('connectorSvg');
  const parent = document.getElementById('nodeParent');
  const parentOut = document.getElementById('parentOut');
  const children = [
    document.getElementById('childTeal'),
    document.getElementById('childGreen'),
    document.getElementById('childOrange')
  ];

  function drawLines() {
    svg.innerHTML = '';
    const svgRect = svg.getBoundingClientRect();
    const startRect = parentOut.getBoundingClientRect();
    
    const startX = startRect.left + startRect.width/2 - svgRect.left;
    const startY = startRect.top + startRect.height/2 - svgRect.top;

    children.forEach(child => {
      const anchorIn = child.querySelector('.anchor-in');
      const endRect = anchorIn.getBoundingClientRect();
      const endX = endRect.left + endRect.width/2 - svgRect.left;
      const endY = endRect.top + endRect.height/2 - svgRect.top;
      
      const dx = Math.abs(endX - startX) * 0.45;
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', `M ${startX} ${startY} C ${startX + dx} ${startY}, ${endX - dx} ${endY}, ${endX} ${endY}`);
      path.setAttribute('stroke', '#a7d6f5');
      path.setAttribute('stroke-width', '1.5');
      path.setAttribute('fill', 'none');
      svg.appendChild(path);
    });
  }

  window.addEventListener('load', drawLines);
  window.addEventListener('resize', drawLines);
  ```

- [ ] **Step 4: 本地调试与效果审查**
  创建完成后，通知用户文件已生成。

---

### Task 2: 暗色思维导图框架卡片布局复刻

**Files:**
- Create: `d:/starmind/prototype/card_layout_dark.html`

- [ ] **Step 1: 创建 HTML 基础架构**
  实现带有网格底纹、根节点徽章和两边不同主题子分区的 HTML 代码结构。
  
  ```html
  <!DOCTYPE html>
  <html lang="zh-CN">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>暗色卡片布局复刻</title>
    <style>
      /* 核心样式在 Step 2 中引入 */
    </style>
  </head>
  <body>
    <div class="viewport">
      <div class="canvas">
        <svg class="connector-canvas" id="connectorSvg"></svg>
        
        <div class="main-card">
          <!-- 悬挂根节点 -->
          <div class="root-badge" id="rootBadge">
            <span class="badge-text">AI配音</span>
            <button class="toggle-btn" onclick="toggleCollapse(this)">−</button>
          </div>
          
          <div class="card-body">
            <!-- 左分区（红色主题） -->
            <div class="partition partition-red" id="partRed">
              <div class="partition-header">
                <span class="partition-badge bg-red">常用平台</span>
                <button class="toggle-btn" onclick="toggleCollapse(this)">−</button>
              </div>
              <div class="partition-content">
                <!-- 国内平台分支 -->
                <div class="branch-group" id="groupDomestic">
                  <div class="node-card node-dark" id="nodeDomestic">
                    <span class="node-text">国内平台</span>
                    <button class="toggle-btn" onclick="toggleCollapse(this)">−</button>
                    <div class="anchor-out" id="domOut"></div>
                  </div>
                  <div class="sub-nodes">
                    <div class="sub-row">
                      <div class="node-pill" id="pillMinimax">
                        <div class="anchor-in"></div>
                        minimax
                      </div>
                      <div class="node-pill" id="pillQianwen">
                        <div class="anchor-in"></div>
                        千问
                      </div>
                    </div>
                    <div class="sub-row">
                      <div class="node-pill" id="pillDoubao">
                        <div class="anchor-in"></div>
                        豆包
                      </div>
                    </div>
                  </div>
                </div>
                <!-- 国外平台分支 -->
                <div class="branch-group">
                  <div class="node-card node-dark" id="nodeForeign">
                    <span class="node-text">国外平台</span>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- 右分区（蓝色主题） -->
            <div class="partition partition-blue" id="partBlue">
              <div class="partition-header">
                <span class="partition-badge bg-blue"><span class="icon">🚩</span>分支主题3</span>
                <button class="toggle-btn" onclick="toggleCollapse(this)">−</button>
              </div>
              <div class="partition-content">
                <div class="branch-group">
                  <div class="node-card node-dark" id="nodeNovel">
                    <span class="node-text">小说</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
      </div>
    </div>
    
    <script>
      // 动态计算连线将在 Step 3 中引入
    </script>
  </body>
  </html>
  ```

- [ ] **Step 2: 写入高保真暗色网格与卡片 CSS 样式**
  构建精致暗色格调。CSS 包含细网格背景 (`linear-gradient`)、带毛玻璃发光的半透明红/蓝外框、纯黑质感圆角节点卡片、高对比度彩色徽章等。
  
  ```css
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  body {
    background-color: #0c0e12;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    color: #eceff4;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    overflow: hidden;
  }
  .viewport {
    position: relative;
    width: 100vw;
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    background-image: 
      linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px),
      linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
    background-size: 20px 20px;
    background-color: #0c0e12;
  }
  .canvas {
    position: relative;
    padding: 120px;
  }
  .connector-canvas {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 1;
  }
  .main-card {
    position: relative;
    z-index: 2;
    background: #171a21;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
    padding: 24px;
    width: 580px;
    box-shadow: 0 15px 40px rgba(0,0,0,0.6);
  }
  .root-badge {
    position: absolute;
    left: 18px;
    top: -15px;
    background: #354556;
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 6px;
    padding: 6px 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: bold;
    color: #ffffff;
    box-shadow: 0 4px 10px rgba(0,0,0,0.3);
  }
  .card-body {
    display: flex;
    gap: 20px;
    margin-top: 14px;
  }
  .partition {
    flex: 1;
    border-radius: 10px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    transition: all 0.3s ease;
  }
  .partition-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .partition-badge {
    font-size: 11.5px;
    font-weight: bold;
    padding: 4px 10px;
    border-radius: 5px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .bg-red {
    background-color: #f65656;
    color: #ffffff;
  }
  .bg-blue {
    background-color: #707df4;
    color: #ffffff;
  }
  .partition-content {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .partition-red {
    background: rgba(246, 86, 86, 0.03);
    border: 1px solid rgba(246, 86, 86, 0.2);
  }
  .partition-blue {
    background: rgba(112, 125, 244, 0.03);
    border: 1px solid rgba(112, 125, 244, 0.2);
  }
  .branch-group {
    display: flex;
    flex-direction: column;
    gap: 12px;
    position: relative;
  }
  .node-card {
    background: #0c0d10;
    border: 1.2px solid #2a2c33;
    border-radius: 6px;
    padding: 8px 14px;
    font-size: 11.5px;
    color: #d8dee9;
    display: inline-flex;
    align-items: center;
    justify-content: space-between;
    align-self: flex-start;
    min-width: 110px;
    position: relative;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .node-card:hover {
    border-color: rgba(255,255,255,0.25);
    transform: translateY(-1px);
  }
  .sub-nodes {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding-left: 20px;
    transition: all 0.3s ease;
  }
  .sub-row {
    display: flex;
    gap: 8px;
  }
  .node-pill {
    background: #0c0d10;
    border: 1px solid #202228;
    border-radius: 5px;
    padding: 5px 12px;
    font-size: 10.5px;
    color: #abb2bf;
    position: relative;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .node-pill:hover {
    color: #ffffff;
    border-color: #3f4452;
  }
  .anchor-out {
    position: absolute;
    right: 0;
    top: 50%;
    transform: translate(50%, -50%);
    width: 5px;
    height: 5px;
    background: rgba(246, 86, 86, 0.6);
    border-radius: 50%;
  }
  .anchor-in {
    position: absolute;
    left: 0;
    top: 50%;
    transform: translate(-50%, -50%);
    width: 5px;
    height: 5px;
    background: rgba(246, 86, 86, 0.6);
    border-radius: 50%;
  }
  .toggle-btn {
    background: transparent;
    border: none;
    color: #636875;
    font-size: 14px;
    cursor: pointer;
    line-height: 1;
    width: 16px;
    height: 16px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 3px;
    transition: all 0.15s;
  }
  .toggle-btn:hover {
    background: rgba(255,255,255,0.06);
    color: #d8dee9;
  }
  /* 折叠状态 CSS */
  .collapsed .sub-nodes,
  .collapsed .partition-content {
    display: none !important;
  }
  .collapsed .toggle-btn {
    transform: rotate(45deg);
    color: #a7d6f5;
  }
  ```

- [ ] **Step 3: 写入 Vanilla JS 连线算法与交互逻辑**
  使用贝塞尔曲线连接“国内平台”与“minimax”、“千问”、“豆包”。同时给所有折叠按钮添加逻辑，折叠后调用 `drawLines()` 刷新线条布局。
  
  ```javascript
  const svg = document.getElementById('connectorSvg');
  const domesticOut = document.getElementById('domOut');
  const pills = [
    document.getElementById('pillMinimax'),
    document.getElementById('pillQianwen'),
    document.getElementById('pillDoubao')
  ];

  function drawLines() {
    svg.innerHTML = '';
    
    // 如果国内平台被折叠了，则不需要画线
    const isDomesticCollapsed = document.getElementById('groupDomestic').classList.contains('collapsed');
    const isRedPartitionCollapsed = document.getElementById('partRed').classList.contains('collapsed');
    if (isDomesticCollapsed || isRedPartitionCollapsed) return;

    const svgRect = svg.getBoundingClientRect();
    const startRect = domesticOut.getBoundingClientRect();
    
    const startX = startRect.left + startRect.width/2 - svgRect.left;
    const startY = startRect.top + startRect.height/2 - svgRect.top;

    pills.forEach(pill => {
      const anchorIn = pill.querySelector('.anchor-in');
      const endRect = anchorIn.getBoundingClientRect();
      const endX = endRect.left + endRect.width/2 - svgRect.left;
      const endY = endRect.top + endRect.height/2 - svgRect.top;
      
      const dx = Math.abs(endX - startX) * 0.45;
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', `M ${startX} ${startY} C ${startX + dx} ${startY}, ${endX - dx} ${endY}, ${endX} ${endY}`);
      path.setAttribute('stroke', 'rgba(246, 86, 86, 0.4)');
      path.setAttribute('stroke-width', '1.2');
      path.setAttribute('fill', 'none');
      svg.appendChild(path);
    });
  }

  function toggleCollapse(btn) {
    const parentNode = btn.parentElement.parentElement;
    parentNode.classList.toggle('collapsed');
    if (btn.innerText === '−') {
      btn.innerText = '+';
    } else {
      btn.innerText = '−';
    }
    // 延迟 redraw 确保 DOM 状态完全更新
    setTimeout(drawLines, 50);
  }

  window.addEventListener('load', drawLines);
  window.addEventListener('resize', drawLines);
  ```

- [ ] **Step 4: 本地调试与效果审查**
  创建完成后，通知用户文件已生成。

---

### Task 3: 整体集成与成果演示

- [ ] **Step 1: 确保文件结构正常并进行验证**
  检查两个生成的文件是否都在 `d:/starmind/prototype/` 目录下，并确保 SVG 连线计算正确。
