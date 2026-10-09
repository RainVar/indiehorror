import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {writeFileSync,mkdirSync} from 'node:fs';
mkdirSync('build/qa',{recursive:true});
const report=[];
const url=(process.env.GAME_URL||'http://127.0.0.1:8061')+'/?qa=1';
const browser=await chromium.launch({headless:true,args:['--mute-audio','--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist','--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream']});
async function ready(context){await context.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('QA prohibits pointer capture');};});const p=await context.newPage();await p.goto(url);await p.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:45000});return p;}
async function cmd(p,d){await p.evaluate(d=>window.bulongCommand(JSON.stringify(d)),d);await p.waitForTimeout(400);}
const check=async(name,fn)=>{await fn();report.push({name,status:'passed'});console.log('PASS',name);};
try{
  await check('microphone denial uses non-mic fallback',async()=>{
    const ctx=await browser.newContext();await ctx.addInitScript(()=>{navigator.mediaDevices.getUserMedia=async()=>{throw new DOMException('Denied for automated test','NotAllowedError');};});
    const p=await ready(ctx);await p.mouse.click(1000,600);await cmd(p,{action:'mic',enabled:true});
    await p.waitForFunction(()=>window.bulongTest.state.mic===false,{},{timeout:6000});
    await cmd(p,{action:'start'});await cmd(p,{action:'close_note'});assert.equal(await p.evaluate(()=>window.bulongTest.state.playing),true);
    await ctx.close();
  });
  await check('synthetic microphone calibration and disconnect',async()=>{
    const ctx=await browser.newContext({permissions:['microphone']});const p=await ready(ctx);await p.mouse.click(1000,600);await cmd(p,{action:'mic',enabled:true});
    await p.waitForFunction(()=>window.bulongTest.state.mic_ready,{},{timeout:12000});
    const privacy=await p.evaluate(()=>({tracks:window.bulongMic.stream.getAudioTracks().length,status:window.bulongMic.status,hasRecorder:!!window.bulongMic.recorder}));
    assert.equal(privacy.status,'ready');assert.equal(privacy.tracks,1);assert.equal(privacy.hasRecorder,false);
    await p.evaluate(()=>{const track=window.bulongMic.stream.getAudioTracks()[0];track.stop();track.dispatchEvent(new Event('ended'));});
    await p.waitForFunction(()=>!window.bulongTest.state.mic,{},{timeout:5000});
    assert.equal(await p.evaluate(()=>window.bulongMic.stream.getTracks()[0].readyState),'ended');
    await ctx.close();
  });
  await check('capture restores checkpoint and control',async()=>{
    const ctx=await browser.newContext();const p=await ready(ctx);await cmd(p,{action:'start'});await cmd(p,{action:'close_note'});
    await cmd(p,{action:'interact',id:'fuse'});await cmd(p,{action:'interact',id:'rules'});await cmd(p,{action:'close_note'});
    await cmd(p,{action:'capture'});await p.waitForTimeout(2400);
    const s=await p.evaluate(()=>window.bulongTest.state);assert.equal(s.act,2);assert.equal(s.paused,false);assert.ok(s.grace>10);
    await ctx.close();
  });
  await check('touch joystick drives the actual player',async()=>{
    const ctx=await browser.newContext({viewport:{width:854,height:480},isMobile:true,hasTouch:true});const p=await ready(ctx);
    await cmd(p,{action:'start'});await cmd(p,{action:'close_note'});await cmd(p,{action:'touch',value:true});
    const before=await p.evaluate(()=>window.bulongTest.state.player[2]);
    const cdp=await ctx.newCDPSession(p);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:85,y:385,id:1}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:85,y:330,id:1}]});
    await p.waitForTimeout(1000);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    await p.waitForTimeout(400);
    assert.ok(await p.evaluate(()=>window.bulongTest.state.player[2])<before-1);
    await p.screenshot({path:'build/qa/touch-input.png'});
    await ctx.close();
  });
  await check('portrait shows readable landscape guidance',async()=>{
    const ctx=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});const p=await ready(ctx);
    await p.screenshot({path:'build/qa/portrait-title.png'});
    assert.equal(await p.locator('#rotate').isVisible(),true);
    assert.ok((await p.locator('#rotate').innerText()).includes('Turn your phone'));
    await ctx.close();
  });
}catch(e){report.push({status:'failed',error:e.stack});console.error(e);process.exitCode=1;}
finally{writeFileSync('build/qa/resilience-report.json',JSON.stringify(report,null,2));await browser.close();}
