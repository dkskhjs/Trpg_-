// index.html의 세계 데이터와 STORY를 Godot용 JSON으로 내보낸다.
//   npm install && npm run export
// 함수로 된 필드(text / cond / fx)는 Godot의 Expression으로 평가할 수 있는 선언형 데이터로 바꾼다.
//   텍스트 줄:  "문장"  |  {if: "식", then: 줄, else: 줄}
//   조건식:     flag("x"), visited("x"), names_count(), has_name("x"), and/or/not
//   치환자:     {names} {names_dot} {names_count}
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const acorn = require('acorn');

const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
const worldSrc = scripts.find(s => s.includes('const ATTRS'));
const storySrc = scripts.find(s => s.includes('const STORY'));

const ctx = vm.createContext({});
const data = vm.runInContext(`${worldSrc}\n${storySrc}\n({ATTRS, SKILLS, ARCHETYPES, THOUGHTS, ITEMS, DIFF, STORY})`, ctx);

function parseFn(fn){
  const src = '(' + fn.toString() + ')';
  const ast = acorn.parseExpressionAt(src, 0, {ecmaVersion: 2022});
  return {src, body: ast.body};
}

function condExpr(src, node){
  let s = src.slice(node.start, node.end);
  s = s.replace(/G\.flags\.(\w+)/g, 'flag("$1")')
       .replace(/G\.visited\.(\w+)/g, 'visited("$1")')
       .replace(/G\.names\.length/g, 'names_count()')
       .replace(/G\.ws\b/g, 'ws()')
       .replace(/G\.names\.includes\('([^']*)'\)/g, 'has_name("$1")')
       .replace(/\|\|/g, ' or ')
       .replace(/&&/g, ' and ')
       .replace(/!(?!=)/g, 'not ');
  if (/G\./.test(s)) throw new Error('변환할 수 없는 조건식: ' + s);
  return s.replace(/\s+/g, ' ').trim();
}

const PLACEHOLDERS = {
  "G.names.join(', ')": '{names}',
  "G.names.join('. ')": '{names_dot}',
  'G.names.length': '{names_count}',
};
function template(src, node){
  let out = '';
  node.quasis.forEach((q, i) => {
    out += q.value.cooked;
    if (i < node.expressions.length){
      const e = node.expressions[i], key = src.slice(e.start, e.end);
      if (!(key in PLACEHOLDERS)) throw new Error('알 수 없는 템플릿 식: ' + key);
      out += PLACEHOLDERS[key];
    }
  });
  return out;
}

function lineOf(src, node){
  switch (node.type){
    case 'Literal': return node.value === '' ? null : node.value;
    case 'TemplateLiteral': return template(src, node);
    case 'ConditionalExpression': {
      const t = lineOf(src, node.consequent), e = lineOf(src, node.alternate);
      if (t === null && e === null) return null;
      const out = {if: condExpr(src, node.test)};
      if (t !== null) out.then = t;
      if (e !== null) out.else = e;
      return out;
    }
  }
  throw new Error('변환할 수 없는 텍스트 식: ' + src.slice(node.start, node.end));
}

function textOf(text){
  if (Array.isArray(text)) return text.filter(t => t !== '');
  const {src, body} = parseFn(text);
  if (body.type !== 'ArrayExpression') throw new Error('text 함수는 배열을 반환해야 함');
  return body.elements.map(e => lineOf(src, e)).filter(x => x !== null);
}

function fxOf(fx){
  if (typeof fx !== 'function') return fx;
  const {src, body} = parseFn(fx);
  if (body.type !== 'ConditionalExpression') throw new Error('fx 함수는 삼항식이어야 함');
  const val = n => vm.runInContext('(' + src.slice(n.start, n.end) + ')', ctx);
  const out = {if: condExpr(src, body.test)};
  const t = val(body.consequent), e = val(body.alternate);
  if (t) out.then = t;
  if (e) out.else = e;
  return out;
}

const story = {};
for (const [id, n] of Object.entries(data.STORY)){
  const out = {scene: n.scene, text: textOf(n.text)};
  if (n.ending) out.ending = true;
  if (n.on) out.on = n.on;
  if (n.passives) out.passives = n.passives;
  if (n.options) out.options = n.options.map(o => {
    const r = {...o};
    if (o.cond){ const {src, body} = parseFn(o.cond); r.cond = condExpr(src, body); }
    if (o.fx) r.fx = fxOf(o.fx);
    return r;
  });
  story[id] = out;
}

const world = {ATTRS: data.ATTRS, SKILLS: data.SKILLS, ARCHETYPES: data.ARCHETYPES, THOUGHTS: data.THOUGHTS, ITEMS: data.ITEMS, DIFF: data.DIFF};
const outDir = path.join(root, 'godot', 'data');
fs.mkdirSync(outDir, {recursive: true});
fs.writeFileSync(path.join(outDir, 'story.json'), JSON.stringify(story, null, 1));
fs.writeFileSync(path.join(outDir, 'world.json'), JSON.stringify(world, null, 1));
console.log(`노드 ${Object.keys(story).length}개 → godot/data/story.json`);
