import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {writeFileSync} from 'node:fs';
const browser=await chromium.launch({headless:true,args:['--mute-audio','--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']});
const context=await browser.newContext({viewport:{width:1280,height:720}});
await context.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('QA prohibits pointer capture');};});
const page=await context.newPage(),errors=[];
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const cmd=async d=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),d);await page.waitForTimeout(200);};
try{
  await page.goto('http://127.0.0.1:8061/?qa=1');await page.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:60000});
  await cmd({action:'start'});await cmd({action:'close_note'});
  for(const id of ['fuse','rules','radio','memory_letter','memory_photo','tomas_clue','binding_portrait','binding_clock','binding_bowl','sewing','baul','pact','matches','radio','altar']){
    await cmd({action:'interact',id});await cmd({action:'close_note'});
  }
  await cmd({action:'teleport',x:-3.3,y:3.65,z:-8,yaw:0,pitch:-12});await cmd({action:'grace',seconds:999});await page.waitForTimeout(700);
  await page.screenshot({path:'build/qa/v02-polish-sewing.png'});
  await cmd({action:'interact',id:'gate'});await page.waitForFunction(()=>window.bulongTest.state.cinematic.active);
  await page.waitForFunction(()=>window.bulongTest.state.cinematic.time>16,{},{timeout:25000});
  await page.screenshot({path:'build/qa/v02-polish-photo.png'});assert.deepEqual(errors,[]);
  await page.keyboard.down('e');await page.waitForTimeout(2300);await page.keyboard.up('e');
  await page.waitForFunction(()=>window.bulongTest.state.modal==='ending',{},{timeout:5000});
  writeFileSync('build/qa/v02-polish-report.json',JSON.stringify({status:'passed',errors},null,2));console.log('PASS final photograph/sewing render, ending skip and no GPU/script errors');
}catch(e){console.error(e);process.exitCode=1;}
finally{await browser.close();}
