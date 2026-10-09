import {chromium,firefox} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
mkdirSync('build/qa',{recursive:true});
const report=[];
const base=process.env.GAME_URL||'http://127.0.0.1:8061';
const browserName=process.env.BROWSER||'chromium';
const browser=await (browserName==='firefox'?firefox:chromium).launch({headless:true,args:browserName==='chromium'?['--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']:[],firefoxUserPrefs:browserName==='firefox'?{'webgl.force-enabled':true}:undefined});
const context=await browser.newContext({viewport:{width:1280,height:720}});
const noPointer=process.env.NO_POINTER==='1';
if(noPointer)await context.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('Pointer lock forbidden in this test run');};});
const page=await context.newPage();
const errors=[];
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const command=async data=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),data);await page.waitForTimeout(320);};
const state=()=>page.evaluate(()=>window.bulongTest.state);
const waitFor=async(fn,timeout=60000)=>{const start=Date.now();while(Date.now()-start<timeout){if(await page.evaluate(fn))return;await new Promise(r=>setTimeout(r,150));}throw new Error('Timed out waiting for game state');};
const check=async(name,fn)=>{await fn();report.push({name,status:'passed'});console.log('PASS',name);};
async function aim(id,from,target){
  const dx=target[0]-from[0],dz=target[2]-from[1];
  const yaw=Math.atan2(-dx,-dz),pitch=Math.atan2(target[1]-1.60,Math.hypot(dx,dz))*180/Math.PI;
  await command({action:'teleport',x:from[0],z:from[1],yaw,pitch});
  await page.waitForTimeout(350);
  const s=await state();
  assert.equal(s.target,id,`Aim at ${id}: got ${s.target} from ${from}, yaw ${yaw}, pitch ${pitch}`);
  await page.keyboard.press('e');
  await page.waitForTimeout(400);
}
try {
  await page.goto(base+'/?qa=1');
  await waitFor(()=>window.bulongTest?.state?.ready);
  await page.waitForTimeout(1800);
  await page.screenshot({path:`build/qa/${browserName}-title.png`});
  await check('startup and render budget',async()=>{
    const s=await state();assert.equal(s.playing,false);assert.ok(s.triangles<200000);assert.ok(s.draws<250);
    report.push({performance:s});
  });
  // Click the real title and onboarding controls rather than the test bridge.
  if(noPointer)await command({action:'touch',value:true});
  await page.mouse.click(215,382);
  await page.waitForTimeout(350);
  await page.screenshot({path:`build/qa/${browserName}-onboarding.png`});
  // Scroll to the primary action in the actual Godot modal.
  await page.mouse.move(920,575);await page.mouse.wheel(0,600);
  await page.waitForTimeout(300);
  await page.mouse.click(480,575);
  await page.waitForTimeout(500);
  assert.equal((await state()).modal,'note','The actual onboarding button starts the story');
  assert.equal(await page.evaluate(()=>document.pointerLockElement!==null),false,'Opening note must not capture the cursor');
  await command({action:'close_note'});
  await check('real keyboard movement and front door',async()=>{
    assert.ok((await state()).player[2]>14,'Start outside the veranda');
    await page.keyboard.down('w');await page.waitForTimeout(2400);await page.keyboard.up('w');
    await page.waitForTimeout(400);
    assert.ok((await state()).player[2]<10,'Cross the patio from the actual spawn');
    await page.keyboard.press('e');
    await page.keyboard.down('w');await page.waitForTimeout(1100);await page.keyboard.up('w');
    assert.ok((await state()).player[2]<8.0,'Player must pass through the opened front door');
  });
  await check('power and note through raycast interactions',async()=>{
    await aim('fuse',[-1.65,6.6],[-1.65,1.5,7.65]);
    assert.ok((await state()).flags.fuse);
    await aim('rules',[0.5,4.55],[0.55,0.84,3.45]);
    assert.equal((await state()).modal,'note');
    await command({action:'close_note'});
    assert.equal((await state()).act,2);
  });
  await command({action:'grace',seconds:999});
  await check('six instructions, inventory and clock',async()=>{
    for(const id of ['door_kitchen','door_family','door_lola','door_store','door_altar'])await command({action:'interact',id});
    await aim('shutter_kitchen',[-7.3,5],[-8.82,1.9,5]);
    await aim('salt',[-4.65,4.4],[-5.55,1.09,4.4]);
    await aim('shutter_family',[-7.3,-1],[-8.82,1.9,-1]);
    await aim('shutter_lola',[7.3,3.5],[8.82,1.9,4]);
    await aim('portrait',[1.2,0.25],[2.7,1.9,0.25]);
    await aim('clock',[-1.2,-2.8],[-2.66,2.05,-2.8]);
    await command({action:'clock',hour:6,minute:30});assert.ok(!(await state()).flags.clock_stopped);
    await command({action:'clock',hour:6,minute:15});
    await aim('threshold',[1.8,-6.2],[3,0.4,-6.2]);
    await aim('portrait',[1.2,0.25],[2.7,1.9,0.25]);
    assert.ok((await state()).flags.key);
  });
  await check('collectibles, baul and final checkpoint',async()=>{
    await aim('memory_letter',[4.1,2.25],[4.1,0.86,1.1]);
    await command({action:'close_note'});
    await aim('memory_photo',[-4.3,-1.9],[-4.3,0.86,-3.1]);
    await command({action:'close_note'});
    await aim('memory_tape',[-5.7,-5.15],[-6.9,0.81,-5.15]);
    await command({action:'close_note'});
    await aim('baul',[-6.2,-6.8],[-6.2,0.63,-8.15]);
    assert.equal((await state()).act,3);assert.equal((await state()).memories,3);
    await aim('pact',[-6.2,-7.25],[-6.2,0.94,-8.45]);
    await command({action:'close_note'});
  });
  await check('pause and checkpoint reload',async()=>{
    await page.keyboard.press('Escape');await page.waitForTimeout(450);assert.equal((await state()).paused,true);
    await page.reload();await waitFor(()=>window.bulongTest?.state?.ready);
    if(noPointer)await command({action:'touch',value:true});
    await page.mouse.click(1120,680);
    await command({action:'continue'});assert.equal((await state()).act,3);assert.equal((await state()).memories,3);
    await command({action:'interact',id:'pact'});await command({action:'close_note'});
    for(const id of ['door_kitchen','door_altar'])await command({action:'interact',id});
  });
  await check('ritual and both endings without microphone',async()=>{
    await command({action:'grace',seconds:999});
    await aim('rice',[-5.0,4.6],[-6.35,1.06,4.6]);
    await aim('altar',[6.2,-7.0],[6.2,1.25,-8.3]);
    await page.keyboard.press('e');await page.waitForTimeout(400);
    assert.ok((await state()).flags.candles);
    await command({action:'grace',seconds:999});
    await page.screenshot({path:`build/qa/${browserName}-altar.png`});
    await command({action:'ritual'});
    await waitFor(()=>window.bulongTest.state.flags.ritual_survived,5000);
    await page.keyboard.press('e');await page.waitForTimeout(300);assert.equal((await state()).modal,'choice');
    await command({action:'choice',kind:'seal'});
    await waitFor(()=>window.bulongTest.state.modal==='ending',7000);
    await page.screenshot({path:`build/qa/${browserName}-ending-seal.png`});
    await command({action:'restart'});
    for(const id of ['pact','rice','altar','altar']){await command({action:'interact',id});if(id==='pact')await command({action:'close_note'});}
    await command({action:'teleport',x:6.2,z:-7,yaw:0});
    await command({action:'grace',seconds:999});await command({action:'ritual'});
    await waitFor(()=>window.bulongTest.state.flags.ritual_survived,5000);
    await command({action:'choice',kind:'break'});
    await waitFor(()=>window.bulongTest.state.modal==='ending',7000);
    assert.equal((await state()).ending,'break');assert.equal((await state()).mic,false);
  });
  await check('low quality and bilingual touch layout',async()=>{
    await command({action:'restart'});await command({action:'quality',value:'low'});
    await command({action:'touch',value:true});await command({action:'language',value:'fil'});
    await page.setViewportSize({width:854,height:480});await page.waitForTimeout(800);
    await page.screenshot({path:`build/qa/${browserName}-touch.png`});
    const s=await state();assert.equal(s.quality,'low');assert.equal(s.language,'fil');assert.ok(s.touch);
    report.push({mobileEmulationPerformance:s});
  });
  await check('no runtime script or browser errors',async()=>assert.deepEqual(errors,[]));
} catch(error) {
  report.push({status:'failed',error:error.stack,state:await state().catch(()=>null),consoleErrors:errors});
  await page.screenshot({path:`build/qa/${browserName}-failure.png`}).catch(()=>{});
  console.error(error);process.exitCode=1;
} finally {
  writeFileSync(`build/qa/${browserName}-report.json`,JSON.stringify(report,null,2));
  await browser.close();
}
