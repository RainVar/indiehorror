import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
const browser=await chromium.launch({headless:true,args:['--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']});
const context=await browser.newContext({viewport:{width:1280,height:720}});
// This visual check must never capture the laptop's cursor.
await context.addInitScript(()=>{
  Element.prototype.requestPointerLock=function(){throw new Error('Mouse capture is forbidden in floor regression');};
});
const page=await context.newPage(),errors=[];
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const command=async data=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),data);await page.waitForTimeout(400);};
const state=()=>page.evaluate(()=>window.bulongTest.state);
const move=async ms=>{await page.keyboard.down('w');await page.waitForTimeout(ms);await page.keyboard.up('w');await page.waitForTimeout(400);};
mkdirSync('build/qa',{recursive:true});
try{
  await page.goto((process.env.GAME_URL||'http://127.0.0.1:8061')+'/?qa=1');
  await page.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:60000});
  await command({action:'touch',value:true});
  await command({action:'start'});await command({action:'close_note'});
  assert.ok((await state()).player[2]>14);
  await move(2400);
  assert.ok((await state()).player[2]<10,'Cross the whole patio without a lip');
  assert.equal((await state()).target,'door_front');
  await page.keyboard.press('e');await page.waitForTimeout(400);await move(1300);
  assert.ok((await state()).player[2]<8,'Cross the floor material seam into the house');
  await command({action:'interact',id:'fuse'});
  for(const [name,x,z,yaw,pitch] of [['inside',0,7.1,0,-46],['inside-angle',0,7.1,0.05,-46],['threshold',0,8.6,0,-60],['patio',1.4,10.7,Math.PI,-50]]){
    await command({action:'teleport',x,z,yaw,pitch});
    await page.screenshot({path:`build/qa/floor-${name}.png`});
  }
  assert.equal(await page.evaluate(()=>document.pointerLockElement!==null),false);
  assert.deepEqual(errors,[]);
  writeFileSync('build/qa/floor-regression.json',JSON.stringify({status:'passed',walkFromSpawn:true,pointerCapture:false,errors},null,2));
  console.log('PASS spawn-to-interior walk and floor views; mouse capture disabled');
}catch(e){console.error(e);process.exitCode=1;}
finally{await browser.close();}
