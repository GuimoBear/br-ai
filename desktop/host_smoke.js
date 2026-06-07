// host_smoke.js — valida a ponte JS<->Lua FORA do Electron (precisa: npm install).
// Uso: node host_smoke.js
const path = require('path');
const host = require('./lua_host');

host.init(path.join(__dirname, '..', 'lua'));

const scenario = {
  grid: { w: 40, h: 40 }, dt: 50, homunId: 100, ownerId: 1,
  entities: [
    { id: 1, kind: 'owner', x: 10, y: 10, hp: 1000, maxhp: 1000 },
    { id: 100, kind: 'homun', x: 20, y: 20, hp: 100, maxhp: 100, sp: 100, maxsp: 100 },
    { id: 200, kind: 'monster', x: 23, y: 23, hp: 40, maxhp: 40, atk: 5, aggro: 8, etype: 1042 },
  ],
};

let s = JSON.parse(host.dispatch('load', JSON.stringify(scenario)));
console.log('load -> tick', s.tick, '| nós da árvore:', s.tree.length);

for (let i = 0; i < 50; i++) s = JSON.parse(host.dispatch('step', ''));
const mob = s.entities.find(e => e.id === 200);
console.log('após 50 passos -> tick', s.tick, '| alvo:', s.target, '| hp monstro:', mob.hp, '| motion:', mob.motion);

const running = s.tree.filter(n => n.status === 'running').map(n => n.label);
console.log('nós RUNNING agora:', running.join(', ') || '(nenhum)');

if (mob.hp === 0) console.log('OK: a IA localizou e matou o monstro pela ponte Fengari.');
else console.log('AVISO: monstro ainda vivo — verifique o cenário/balanceamento.');
