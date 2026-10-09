import {chromium,firefox} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
const name=process.env.BROWSER||'chromium';
const browser=await (name==='firefox'?firefox:chromium).launch({headless:true,args:name==='chromium'?['--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']:[],firefoxUserPrefs:name==='firefox'?{'webgl.force-enabled':true}:undefined});
const context=await browser.newContext({viewport:{width:1280,height:720}});
await context.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('Pointer capture forbidden during surface inspection');};});
const page=await context.newPage(),errors=[],samples=[];
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const cmd=async data=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),data);await page.waitForTimeout(300);};
const state=()=>page.evaluate(()=>window.bulongTest.state);
const scenes=[['sala',0,6.7,0,-15],['sala-ceiling',0,4,0,50],['hall-joints',0,-2,Math.PI/2,10],['kitchen',-4.4,6.7,0.5,-12],['window',-7.3,5,Math.PI/2,8],['family-room',-4.4,0.8,0,-20],['lola-room',4.5,6.8,-0.5,-15],['storeroom',-4.7,-5.2,0.4,-12],['altar',5,-5,-0.25,0],['altar-cross',6.2,-7,0,15],['exterior',0,15.2,0,10],['clock',-1.5,-2.8,Math.PI/2,18],['portrait',1.5,0.25,-Math.PI/2,10]];
const selectedScenes=process.env.SCENE_FILTER?scenes.filter(s=>process.env.SCENE_FILTER.split(',').includes(s[0])):scenes;
mkdirSync('build/qa/surfaces',{recursive:true});
try{
  await page.goto((process.env.GAME_URL||'http://127.0.0.1:8061')+'/?qa=1');
  const begin=Date.now();
  while(!await page.evaluate(()=>window.bulongTest?.state?.ready)){
    if(Date.now()-begin>90000)throw new Error('Game startup timeout');
    await page.waitForTimeout(200);
  }
  await cmd({action:'touch',value:true});await cmd({action:'start'});await cmd({action:'close_note'});
  await cmd({action:'grace',seconds:999});await cmd({action:'interact',id:'fuse'});
  const audit=(await state()).surfaces;
  assert.equal(audit.remaining_conflicts,0);
  assert.ok(audit.priority_resolutions>0);
  for(const quality of (process.env.QUALITY?[process.env.QUALITY]:['low','high'])){
    await cmd({action:'quality',value:quality});
    for(const [scene,x,z,yaw,pitch] of selectedScenes){
      await cmd({action:'teleport',x,z,yaw,pitch});await page.waitForTimeout(1000);
      const arrived=Date.now();
      while(Math.abs((await state()).player[0]-x)>0.2 || Math.abs((await state()).player[2]-z)>0.2){
        if(Date.now()-arrived>10000)throw new Error(`Telemetry did not reach ${scene}`);
        await page.waitForTimeout(200);
      }
      const s=await state();
      samples.push({quality,scene,fps:s.fps,draws:s.draws,triangles:s.triangles,vram_mb:Math.round(s.vram/1048576*10)/10});
      assert.ok(s.draws<300,`${quality}/${scene}: ${s.draws} draw calls exceeds 300`);
      assert.ok(s.triangles<50000,`${quality}/${scene}: ${s.triangles} triangles exceeds 50000`);
      await page.screenshot({path:`build/qa/surfaces/${name}-${quality}-${scene}.png`});
      // Slightly change the viewpoint to reveal remaining coplanar issues.
      await cmd({action:'teleport',x:x+0.015,z,yaw:yaw+0.015,pitch});
      if(quality==='high')await page.screenshot({path:`build/qa/surfaces/${name}-${quality}-${scene}-angle.png`});
    }
  }
  await cmd({action:'interact',id:'rules'});await cmd({action:'close_note'});
  await cmd({action:'grace',seconds:999});
  for(const id of ['door_front','door_kitchen','shutter_kitchen','portrait'])await cmd({action:'interact',id});
  assert.ok((await state()).flags.shutter_kitchen);
  assert.ok((await state()).flags.portrait);
  await cmd({action:'clock',hour:6,minute:15});
  assert.equal(await page.evaluate(()=>!!document.pointerLockElement),false);
  assert.deepEqual(errors,[]);
  writeFileSync(`build/qa/surfaces/${name}-${process.env.SCENE_FILTER?'focused-':''}report.json`,JSON.stringify({status:'passed',audit,samples,errors,pointerCapture:false},null,2));
  console.log(JSON.stringify({status:'passed',browser:name,audit,views:samples.length,minSampleFPS:Math.min(...samples.map(s=>s.fps)),maxDraws:Math.max(...samples.map(s=>s.draws)),maxTriangles:Math.max(...samples.map(s=>s.triangles))}));
}catch(e){writeFileSync(`build/qa/surfaces/${name}-failure-report.json`,JSON.stringify({error:String(e),samples,state:await state(),errors},null,2));console.error(e);process.exitCode=1;}
finally{await browser.close();}
