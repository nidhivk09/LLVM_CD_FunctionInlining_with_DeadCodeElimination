let state = { files: [], selected: null, threshold: 45, data: null, step: 1 };

function switchTab(name){
  document.querySelectorAll('.tab').forEach((t,i)=>{
    t.classList.toggle('active', ['ir','summary'][i] === name);
  });
  document.querySelectorAll('.tab-content').forEach(el=>el.classList.remove('active'));
  document.getElementById('tab-'+name).classList.add('active');
  if(name === 'summary') renderSummary();
}

function setStep(step) {
    state.step = step;
    document.querySelectorAll('.step-btn').forEach((btn, idx) => {
        btn.classList.toggle('active', idx + 1 === step);
    });
    renderTimeline();
}

// ── Syntax highlighting ────────────────────────────────────────────────────
const KW=/\b(define|declare|call|ret|br|load|store|alloca|getelementptr|icmp|fcmp|add|sub|mul|sdiv|udiv|srem|urem|and|or|xor|shl|lshr|ashr|phi|select|switch|invoke|unreachable|i1|i8|i16|i32|i64|i128|float|double|void|ptr|label|align|nsw|nuw|exact|inbounds|true|false|null|zeroinitializer|undef)\b/g;
const CKW=/\b(int|void|return|if|else|while|for|do|struct|typedef|char|long|short|unsigned|float|double|const|static)\b/g;
const GL=/@[\w.]+/g;const LC=/%[\w.]+/g;const NM=/\b-?\d+\b/g;
const CM=/;.*$/;const CCM=/\/\/.*$/;const LBL=/^\s*[\w.]+:$/;
function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}

function colorizeLine(line, isC = false){
  if(isC){
    const ccm = CCM.exec(line);
    if(ccm) return tokenizeC(line.slice(0,ccm.index))+`<span class="syntax-cm">${esc(line.slice(ccm.index))}</span>`;
    return tokenizeC(line);
  }
  const cm=CM.exec(line);
  if(cm) return tokenize(line.slice(0,cm.index))+`<span class="syntax-cm">${esc(line.slice(cm.index))}</span>`;
  if(LBL.test(line)) return `<span class="syntax-lb">${esc(line)}</span>`;
  return tokenize(line);
}

function tokenizeC(text){
  const spans=[],used=new Set();
  const add=(re,cls)=>{re.lastIndex=0;let m;while((m=re.exec(text))!==null){let ok=true;for(let i=m.index;i<m.index+m[0].length;i++)if(used.has(i)){ok=false;break}if(ok){for(let i=m.index;i<m.index+m[0].length;i++)used.add(i);spans.push({s:m.index,e:m.index+m[0].length,cls})}}};
  add(CKW,'syntax-kw');add(NM,'syntax-nm');
  if(!spans.length)return esc(text);
  spans.sort((a,b)=>a.s-b.s);
  let out='',pos=0;
  for(const{s,e,cls}of spans){if(s>pos)out+=esc(text.slice(pos,s));out+=`<span class="${cls}">${esc(text.slice(s,e))}</span>`;pos=e}
  if(pos<text.length)out+=esc(text.slice(pos));
  return out;
}

function tokenize(text){
  const spans=[],used=new Set();
  const add=(re,cls)=>{re.lastIndex=0;let m;while((m=re.exec(text))!==null){let ok=true;for(let i=m.index;i<m.index+m[0].length;i++)if(used.has(i)){ok=false;break}if(ok){for(let i=m.index;i<m.index+m[0].length;i++)used.add(i);spans.push({s:m.index,e:m.index+m[0].length,cls})}}};
  add(GL,'syntax-gl');add(LC,'syntax-lc');add(KW,'syntax-kw');add(NM,'syntax-nm');
  if(!spans.length)return esc(text);
  spans.sort((a,b)=>a.s-b.s);
  let out='',pos=0;
  for(const{s,e,cls}of spans){if(s>pos)out+=esc(text.slice(pos,s));out+=`<span class="${cls}">${esc(text.slice(s,e))}</span>`;pos=e}
  if(pos<text.length)out+=esc(text.slice(pos));
  return out;
}

function renderIR(ir,diffClass,isBeforePanel=false,isC=false){
  if(!ir)return '<span style="color:var(--text-muted);font-size:12px">Not available</span>';
  return ir.split('\n').map(line=>{
    let cls='';
    if(!isC&&isBeforePanel&&/\bcall\b/.test(line)&&!line.includes('llvm.'))cls='hl-call';
    const colored=colorizeLine(line,isC);
    return cls?`<span class="${cls}">${colored}</span>`:colored;
  }).join('\n');
}

function renderSyncIR(syncLines, isBeforePanel=false, isC=false){
  if(!syncLines || syncLines.length === 0) return '<span style="color:var(--text-muted);font-size:12px">Not available</span>';
  const showDiff=document.getElementById('diff-toggle').checked;
  return syncLines.map(lineObj => {
    const text = lineObj.text;
    const type = lineObj.type; 
    
    if (type === 'empty') return `<span style="display:block;height:1.7em;user-select:none"> </span>`;

    let cls='';
    if(!isC&&isBeforePanel&&/\bcall\b/.test(text)&&!text.includes('llvm.'))cls='hl-call';
    if(!isC&&showDiff) {
       if(type === 'delete') cls='hl-del';
       if(type === 'insert') cls='hl-add';
    }
    
    const colored=colorizeLine(text,isC);
    if (!text.trim()) return cls?`<span class="${cls}" style="display:block;height:1.7em"> </span>`:`<span style="display:block;height:1.7em"> </span>`;
    return cls?`<span class="${cls}">${colored}</span>`:colored;
  }).join('\n');
}


// ── Cost Charts ────────────────────────────────────────────────────────────
function renderCostCharts(decisions, threshold) {
    if (!decisions || decisions.length === 0) return `<span style="color:var(--text-muted);font-size:12px">No cost data available.</span>`;
    
    // Find max cost for scaling
    const maxCost = Math.max(threshold, ...decisions.map(d => d.cost || 0));
    
    return decisions.map(d => {
        if (d.cycle) return ''; // Skip cycles
        
        const cost = d.cost || 0;
        const widthPct = Math.min(100, (cost / maxCost) * 100);
        const thresholdPct = Math.min(100, (threshold / maxCost) * 100);
        
        const color = cost >= threshold ? 'var(--skip)' : 'var(--inline)';
        
        return `
            <div class="cost-row">
                <div class="cost-label">@${d.name}</div>
                <div class="cost-bar-container">
                    <div class="cost-bar-fill" style="width: ${widthPct}%; background: ${color};"></div>
                    <div class="cost-threshold-line" style="left: ${thresholdPct}%;"></div>
                </div>
                <div class="cost-value">${cost}</div>
            </div>
        `;
    }).join('');
}

// ── Main UI render ─────────────────────────────────────────────────────────
function render() {
  const d = state.data;
  if(!d) return;

  document.getElementById('page-title').textContent = state.selected || '—';

  // Cards
  document.getElementById('cards-row').innerHTML =
    d.decisions.length ? d.decisions.map(dec => {
      const cls=dec.decision.toLowerCase();
      const math=dec.cycle?'Recursive - Blocked':`${dec.instrs} &times; ${dec.calls} = <b>${dec.cost_str}</b>`;
      return `<div class="card ${cls}">
        <div class="card-name">@${dec.name}</div>
        <div class="card-verdict">${dec.decision}</div>
        <div class="card-reason">${dec.reason}</div>
        <hr class="card-divider">
        <div class="card-math">${math}</div>
      </div>`;
    }).join('') : '<span style="color:var(--text-muted);font-size:12px">No non-main functions found.</span>';

  // Metrics
  const ms = document.getElementById('metrics-section');
  if(d.metrics){
    ms.style.display='';
    const m=d.metrics;
    
    const renderMetric = (label, val, delta) => {
        let dh='';
        if(delta!==undefined){const sign=delta>0?'+':'';const cls=delta>0?'delta-pos':'delta-neg';dh=`<div class="metric-delta ${cls}">${sign}${delta}</div>`}
        return `<div class="metric"><div class="metric-label">${label}</div><div class="metric-value">${val}</div>${dh}</div>`;
    }

    document.getElementById('metrics-row').innerHTML=
      renderMetric('Functions', m.funcs_after, m.funcs_after - m.funcs_before) +
      renderMetric('Calls', m.calls_after, m.calls_after - m.calls_before) +
      renderMetric('IR Reduction', m.pct + '%');
  } else ms.style.display='none';


  
  // Render Cost Charts
  document.getElementById('cost-charts').innerHTML = renderCostCharts(d.decisions, state.threshold) + 
     `<div style="font-size: 10px; color: var(--text-muted); text-align: center; margin-top: 8px;">Red line indicates threshold (${state.threshold})</div>`;

  renderTimeline();
}

function renderTimeline() {
    const d = state.data;
    if(!d) return;

    const container = document.getElementById('code-container');
    const legend = document.getElementById('legend');
    
    const s1 = document.getElementById('step-1');
    const s2 = document.getElementById('step-2');
    const s3 = document.getElementById('step-3');
    const s4 = document.getElementById('step-4');
    const s5 = document.getElementById('step-5');

    // Update active visual step
    s1.classList.toggle('active', state.step >= 1);
    s2.classList.toggle('active', state.step >= 2);
    s3.classList.toggle('active', state.step >= 3);
    s4.classList.toggle('active', state.step >= 4);
    s5.classList.toggle('active', state.step >= 5);

    legend.style.display = 'none';

    if (state.step === 1) {
        container.innerHTML = `
          <div class="ir-row">
            <div class="ir-panel">
              <div class="ir-label"><span class="ir-dot" style="background:#5a7fa8"></span>Original C Source</div>
              <div class="ir-code">${renderIR(d.c_code,'',false,true)}</div>
            </div>
          </div>
        `;
    } else if (state.step === 2) {
        container.innerHTML = `
          <div class="ir-row">
            <div class="ir-panel">
              <div class="ir-label"><span class="ir-dot" style="background:#e5b4b4"></span>Initial LLVM IR (Phase 0)</div>
              <div class="ir-code">${renderIR(d.before_ir,'hl-call',true,false)}</div>
            </div>
          </div>
        `;
    } else if (state.step === 3) {
        legend.style.display = 'flex';
        // Compare Before IR with Inlined IR (Mocked intermediate state)
        if (d.inlined_ir) {
            container.innerHTML = `
              <div class="ir-row diff-mode">
                <div class="ir-panel">
                  <div class="ir-label"><span class="ir-dot" style="background:#e5b4b4"></span>Before Inlining</div>
                  <div class="ir-code">${renderIR(d.before_ir,'hl-call',true,false)}</div>
                </div>
                <div class="ir-panel">
                  <div class="ir-label"><span class="ir-dot" style="background:#e8c97a"></span>After Inlining (Pre-DCE)</div>
                  <div class="ir-code">${renderIR(d.inlined_ir,'hl-add',false,false)}</div>
                </div>
              </div>
            `;
        } else {
             container.innerHTML = `<div class="ir-row"><div class="ir-panel"><div class="ir-code">Intermediate IR not available.</div></div></div>`;
        }
    } else if (state.step === 4) {
        legend.style.display = 'flex';
        if (d.after_ir) {
            container.innerHTML = `
              <div class="ir-row diff-mode">
                <div class="ir-panel">
                  <div class="ir-label"><span class="ir-dot" style="background:#e8c97a"></span>Pre-DCE</div>
                  <div class="ir-code">${renderIR(d.inlined_ir,'hl-del',false,false)}</div>
                </div>
                <div class="ir-panel">
                  <div class="ir-label"><span class="ir-dot" style="background:#90c49a"></span>After DCE (Final IR)</div>
                  <div class="ir-code">${renderIR(d.after_ir,'hl-add',false,false)}</div>
                </div>
              </div>
            `;
        } else {
             container.innerHTML = `<div class="ir-row"><div class="ir-panel"><div class="ir-code">Output IR not available. Run pass first.</div></div></div>`;
        }
    } else if (state.step === 5) {
        container.innerHTML = `
          <div class="ir-row diff-mode">
            <div class="ir-panel">
              <div class="ir-label"><span class="ir-dot" style="background:#5a7fa8"></span>Original C Source</div>
              <div class="ir-code">${renderIR(d.c_code,'',false,true)}</div>
            </div>
            <div class="ir-panel">
              <div class="ir-label"><span class="ir-dot" style="background:#90c49a"></span>Conceptual "After" C Source</div>
              <div class="ir-code">${renderIR(d.c_after_code || 'No mock C code found for this test.','',false,true)}</div>
            </div>
          </div>
        `;
    }
}

function computeDecisions(d, threshold) {
  const decisions = [];
  if (!d.functions) return;
  for (const fn of d.functions) {
    let decision, reason, cost_str;
    if (fn.cycle) {
      decision = "BLOCKED";
      reason = "cycle detected in call graph";
      cost_str = "—";
    } else if (fn.calls === 0) {
      decision = "SKIP";
      reason = "0 call sites in module";
      cost_str = "0";
    } else if (fn.cost >= threshold) {
      decision = "SKIP";
      reason = `cost ${fn.cost} ≥ threshold ${threshold}`;
      cost_str = String(fn.cost);
    } else {
      decision = "INLINE";
      reason = `cost ${fn.cost} < threshold ${threshold}`;
      cost_str = String(fn.cost);
    }
    decisions.push({
      name: fn.name,
      instrs: fn.instrs,
      calls: fn.calls,
      cost: fn.cost,
      cost_str: cost_str,
      cycle: fn.cycle,
      decision: decision,
      reason: reason
    });
  }
  d.decisions = decisions;
}

// ── Data fetching ──────────────────────────────────────────────────────────
async function load(file){
  state.selected=file;
  document.querySelectorAll('.file-item').forEach(el=>{
    el.classList.toggle('active',el.dataset.file===file);
  });
  
  if (!window.LLVM_DATA) {
      console.error("No data available. Please run export_data.py first.");
      return;
  }
  
  state.data = Object.assign({}, window.LLVM_DATA.results[file]);
  computeDecisions(state.data, state.threshold);
  
  // Render the static parts (cards, call graph, cost charts)
  render();
  // Set to step 1 and render the timeline code viewer
  setStep(1);
}

async function loadFiles(){
  if (!window.LLVM_DATA) {
      document.getElementById('file-list').innerHTML = '<div style="padding:10px;color:red;">Data missing.<br>Run <b>export_data.py</b> first.</div>';
      return;
  }
  state.files = window.LLVM_DATA.files;
  const list=document.getElementById('file-list');
  list.innerHTML=state.files.map(f=>
    `<div class="file-item" data-file="${f}" onclick="load('${f}')">${f}</div>`
  ).join('');
  if(state.files.length) load(state.files[0]);
}

async function renderSummary(){
  const wrap = document.getElementById('summary-table-wrap');
  wrap.innerHTML = '<span style="color:var(--text-muted);font-size:12px;font-family:var(--font-mono)">Analyzing test suite...</span>';

  if (!window.LLVM_DATA) return;
  
  const allResults = state.files.map(f => {
    const d = Object.assign({}, window.LLVM_DATA.results[f]);
    computeDecisions(d, state.threshold);
    return { file: f, ...d };
  });

  const maxReduction = Math.max(...allResults.filter(r=>r.metrics).map(r=>r.metrics.pct), 1);

  const rows = allResults.map(r => {
    const m = r.metrics;
    const inlined  = r.decisions.filter(x=>x.decision==='INLINE').map(x=>`@${x.name}`);
    const pct = m ? m.pct : null;
    const barWidth = pct ? Math.round((pct / maxReduction) * 100) : 0;
    
    return `<tr onclick="load('${r.file}');switchTab('ir')" style="cursor:pointer">
      <td>${r.file.replace('.c','')}</td>
      <td>${inlined.length ? inlined.length : '0'} functions</td>
      <td>${m ? (m.funcs_after - m.funcs_before) : '—'}</td>
      <td>${m ? (m.calls_after - m.calls_before) : '—'}</td>
      <td>${pct !== null ? `<div class="bar-wrap"><div class="bar-bg"><div class="bar-fill" style="width:${barWidth}%"></div></div><span>${pct}%</span></div>` : '—'}</td>
    </tr>`;
  }).join('');

  wrap.innerHTML = `
    <table class="summary-table">
      <thead>
        <tr>
          <th>Test Name</th>
          <th>Inlined</th>
          <th>Fn Delta</th>
          <th>Call Delta</th>
          <th>IR Reduction</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function onThreshold(val){
  state.threshold=parseInt(val);
  document.getElementById('threshold-val').textContent=val;
  if(state.selected) load(state.selected);
}

loadFiles().then(()=>{ 
    setTimeout(() => {
        const loader = document.getElementById('loading');
        loader.style.opacity = '0';
        setTimeout(() => loader.style.display='none', 300);
    }, 500);
});
