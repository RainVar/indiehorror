// Original deterministic textures and sound design. No network calls or recordings.
import { mkdirSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
const root = new URL('../assets/', import.meta.url);
mkdirSync(new URL('textures/', root), { recursive: true });
mkdirSync(new URL('audio/', root), { recursive: true });
let seed = 71254;
function rand() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }
function crc(b) { let c = -1; for (const x of b) { c ^= x; for (let i=0;i<8;i++) c = (c>>>1) ^ (0xedb88320 & -(c&1)); } return (c^-1)>>>0; }
function chunk(type, body) { const t=Buffer.from(type), n=Buffer.alloc(4), c=Buffer.alloc(4); n.writeUInt32BE(body.length); c.writeUInt32BE(crc(Buffer.concat([t,body]))); return Buffer.concat([n,t,body,c]); }
function png(name, fn, size=256) {
  const raw=Buffer.alloc((size*3+1)*size);
  for(let y=0;y<size;y++) for(let x=0;x<size;x++) {
    const rgb=fn(x,y,size); for(let k=0;k<3;k++) raw[y*(size*3+1)+x*3+1+k]=Math.max(0,Math.min(255,Math.round(rgb[k])));
  }
  const h=Buffer.alloc(13); h.writeUInt32BE(size,0); h.writeUInt32BE(size,4); h[8]=8; h[9]=2;
  writeFileSync(new URL(`textures/${name}.png`,root),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',h),chunk('IDAT',deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]));
}
png('wood',(x,y)=>{const seam=x%64<2||y%128<2;const n=rand()*16+Math.sin(y*.095+Math.sin(x*.034)*3)*8+Math.sin(y*.67+x*.032)*4;const v=seam?-25:((x/64|0)%2)*7;return[95+n+v,71+n*.65+v,47+n*.35+v];});
png('plaster',(x,y)=>{const n=rand()*14+Math.sin(x*.027)*4+Math.sin(y*.07)*3;const stain=Math.max(0,Math.sin(x*.093+Math.sin(y*.03))*Math.cos(y*.014)-.4)*34;return[137+n-stain,129+n-stain,107+n-stain];});
png('mold',(x,y)=>{const n=rand()*18;const stain=Math.max(0,Math.sin(x*.07+Math.sin(y*.04)*2)+Math.cos(y*.08+x*.022))*25;return[111+n-stain,121+n-stain*.75,106+n-stain];});
png('tiles',(x,y)=>{const seam=x%64<3||y%64<3;const n=rand()*9;const alt=((x/64|0)+(y/64|0))%2;return seam?[40,47,43]:alt?[93+n,108+n,96+n]:[143+n,140+n,112+n];});
png('capiz',(x,y)=>{const seam=x%32<3||y%32<3;const n=rand()*13+Math.sin(x*.3+y*.5)*6;return seam?[69,56,38]:[181+n,171+n,132+n];});
png('woven',(x,y)=>{const n=rand()*8;const w=((x/8|0)+(y/8|0))%2;const line=w?y%8:x%8;return[112+n+line*4,87+n+line*3,52+n+line*2];});
png('concrete',(x,y)=>{const n=rand()*24+Math.sin(x*.1+y*.3)*4;return[61+n,66+n,61+n];});
png('paper',(x,y)=>{const edge=Math.min(x,y,255-x,255-y);const n=rand()*8-Math.max(0,16-edge)*1.5;return[196+n,181+n,145+n];});
function wav(name,seconds,fn,rate=22050){const count=Math.floor(seconds*rate), b=Buffer.alloc(44+count*2);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(count*2,40);let prev=0;for(let i=0;i<count;i++){const t=i/rate;const n=rand()*2-1;prev=.72*prev+.28*n;const sample=fn(t,n,prev,seconds);b.writeInt16LE(Math.round(Math.max(-1,Math.min(1,sample))*32760),44+i*2);}writeFileSync(new URL(`audio/${name}.wav`,root),b);}
wav('rain',8,(t,n,p)=>n*.07+p*.34+Math.sin(t*2800)*Math.max(0,Math.sin(t*17.3)-.997)*2);
wav('wind',10,(t,n,p)=>p*.3*(.6+Math.sin(t*.628)*.2)+Math.sin(t*37.7)*.025);
wav('drone',10,(t,n,p)=>Math.sin(t*2*Math.PI*44)*.12+Math.sin(t*2*Math.PI*66)*.055+Math.sin(t*2*Math.PI*44.2)*.05+p*.015);
wav('step',.26,(t,n,p)=>Math.exp(-t*23)*(p*.45+Math.sin(t*410)*.16));
wav('knock',.55,(t,n,p)=>Math.exp(-t*18)*(Math.sin(t*730)*.42+Math.sin(t*319)*.3+p*.14));
wav('creak',1.6,(t,n,p,s)=>Math.sin(Math.PI*t/s)*(.1*Math.sin(t*1100+Math.sin(t*22)*11)+.09*Math.sin(t*1690+Math.sin(t*31)*9)+p*.12));
wav('whisper',2.8,(t,n,p,s)=>Math.pow(Math.sin(Math.PI*t/s),2)*(.3*(n-p))*(.5+.4*Math.sin(t*19)));
wav('chime',2,(t)=>Math.exp(-t*3)*(Math.sin(t*2*Math.PI*523)*.17+Math.sin(t*2*Math.PI*783)*.08));
wav('impact',1.8,(t,n,p)=>Math.exp(-t*3)*(p*.8+Math.sin(t*(220-t*55))*.45));
wav('heartbeat',1,(t)=>{const a=t%1;return Math.sin(t*360)*(.45*Math.exp(-a*40)+.3*Math.exp(-Math.max(0,a-.22)*40)*(a>.22?1:0));});
wav('match',.7,(t,n,p)=>Math.exp(-t*7)*(n*.26+p*.3));
wav('phone',2,(t)=>Math.sin(t*2*Math.PI*780)*.12*(Math.sin(t*28)>0?1:0)*(.6+.4*Math.sin(t*3)));
wav('thunder',5,(t,n,p)=>Math.sin(Math.PI*t/5)*Math.exp(-t*.3)*(p*.65+Math.sin(t*53)*.09));
console.log('Generated 8 original textures and 13 original sound effects.');
