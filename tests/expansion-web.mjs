import {chromium,firefox} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
mkdirSync('build/qa',{recursive:true});
const name=process.env.BROWSER||'chromium';
const browser=await (name==='firefox'?firefox:chromium).launch({headless:true,args:name==='chromium'?['--mute-audio','--use-angle=d3d11','--enable-webgl','--ignore-gpu-blocklist']:[],firefoxUserPrefs:name==='firefox'?{'webgl.force-enabled':true,'media.volume_scale':'0.0'}:undefined});
const context=await browser.newContext({viewport:{width:1280,height:720}});
await context.addInitScript(()=>{Element.prototype.requestPointerLock=function(){throw new Error('QA prohibits cursor capture');};});
const page=await context.newPage(),errors=[],report=[],samples=[];
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const state=()=>page.evaluate(()=>window.bulongTest.state);
const cmd=async d=>{await page.evaluate(d=>window.bulongCommand(JSON.stringify(d)),d);await page.waitForTimeout(220);};
const ready=()=>page.waitForFunction(()=>window.bulongTest?.state?.ready,{},{timeout:60000});
const check=async(label,fn)=>{await fn();report.push({name:label,status:'passed'});console.log('PASS',label);};
const close=async()=>{if((await state()).modal==='note')await cmd({action:'close_note'});};
const interact=async id=>{await cmd({action:'interact',id});await close();};
const move=async(key,ms)=>{await page.keyboard.down(key);await page.waitForTimeout(ms);await page.keyboard.up(key);await page.waitForTimeout(200);};
const walkUntil=async(key,predicate,arg)=>{
  await page.keyboard.down(key);
  try{await page.waitForFunction(predicate,arg,{timeout:20000});}
  finally{await page.keyboard.up(key);}
  await page.waitForTimeout(200);
};
async function aim(id,from,hold=0){
  const target=(await state()).items[id];assert.ok(target,`Item ${id} exists`);
  const [x,y,z]=from,dx=target[0]-x,dz=target[2]-z;
  await cmd({action:'teleport',x,y,z,yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(target[1]-y-(y<-.6?.9:1.62),Math.hypot(dx,dz))*180/Math.PI});
  await page.waitForTimeout(220);
  assert.equal((await state()).target,id,`Raycast ${id} from ${from}; got ${(await state()).target}`);
  if(hold){await page.keyboard.down('e');await page.waitForTimeout(hold);await page.keyboard.up('e');}
  else await page.keyboard.press('e');
  await page.waitForTimeout(260);
}
async function screenshot(label){await page.screenshot({path:`build/qa/${name}-v02-${label}.png`});}
async function waitFlag(flag,timeout=15000){await page.waitForFunction(f=>window.bulongTest.state.flags[f],flag,{timeout});}
try{
  await page.goto((process.env.GAME_URL||'http://127.0.0.1:8061')+'/?qa=1');await ready();await page.waitForTimeout(1000);
  await check('silent startup, no cursor capture and clean geometry',async()=>{
    const s=await state();assert.ok(s.muted);assert.equal(s.surfaces.remaining_conflicts,0);assert.equal(s.playing,false);
    assert.equal(await page.evaluate(()=>document.pointerLockElement),null);await screenshot('title');
  });
  await cmd({action:'start'});assert.equal((await state()).modal,'note');await close();
  await check('walk across patio and through actual front door',async()=>{
    await walkUntil('w',()=>window.bulongTest.state.player[2]<9.6);assert.ok((await state()).player[2]<10);
    assert.equal((await state()).target,'door_front');await page.keyboard.press('e');await page.waitForTimeout(500);
    await walkUntil('w',()=>window.bulongTest.state.player[2]<7.2);
    assert.ok((await state()).player[2]<8,JSON.stringify((await state()).player));
  });
  await check('power and instructions through actual raycasts',async()=>{
    await aim('fuse',[-1.7,.05,6.5]);assert.ok((await state()).flags.fuse);
    await aim('rules',[-6.5,.05,5.5]);await close();assert.ok((await state()).flags.rules);
  });
  await cmd({action:'grace',seconds:999});
  if(!process.env.RELEASE_ONLY){
  for(const id of ['service_stairs','foyer_stairs','foyer_gallery','dining_hall','pantry_hall','altar','family','guest','study','lola','sewing','tomas_hall','tomas','store'])await interact('door_'+id);
  await check('both staircases support walking up and down without jumping',async()=>{
    for(const [label,x,z] of [['main',4.4,7.5],['service',-9.6,-4.5]]){
      await cmd({action:'teleport',x,y:.05,z,yaw:0});await walkUntil('w',s=>window.bulongTest.state.player[1]>3.45&&window.bulongTest.state.player[2]<s-6.7,z);
      const top=(await state()).player;assert.ok(top[1]>3.45,`${label} stair top ${top}`);await screenshot(label+'-stairs');
      await walkUntil('s',s=>window.bulongTest.state.player[1]<.2&&window.bulongTest.state.player[2]>s-.2,z);const bottom=(await state()).player;assert.ok(bottom[1]<.2,`${label} stair bottom ${bottom}`);
    }
  });
  await check('creature physically follows a vertical stair route',async()=>{
    await cmd({action:'teleport',x:-7,y:.05,z:6,yaw:0});
    await cmd({action:'entity_path',x:4.4,y:.05,z:7.5,tx:4.4,ty:3.65,tz:.3});
    await page.waitForFunction(()=>window.bulongTest.state.entity_position[1]>3.4,{},{timeout:16000});
    await cmd({action:'entity_reset'});await cmd({action:'grace',seconds:999});
  });
  await check('real early hold action commits only to Keeper',async()=>{
    await aim('rice',[-7,.05,-7]);assert.ok((await state()).flags.rice);
    await aim('altar',[7,.05,-7.9],1700);await close();assert.equal((await state()).route,'KEEPER');
    await interact('radio');assert.equal((await state()).route,'KEEPER');
  });
  await check('keeper wards, winding key and baul have distinct prerequisites',async()=>{
    await aim('shutter_kitchen',[-7.4,.05,-10.6]);
    await aim('shutter_lola',[-6.5,3.65,-10.6]);
    await aim('shutter_family',[9.5,3.65,5]);
    await aim('portrait',[-4.6,.05,-2]);
    await aim('salt',[-6.5,.05,-7]);
    await aim('threshold',[2,.05,-5.4]);
    await aim('winding_key',[-5.4,3.65,-.6]);
    await aim('clock',[-9.5,.05,-1]);assert.equal((await state()).modal,'clock');
    await cmd({action:'clock',hour:6,minute:30});assert.ok(!(await state()).flags.clock_stopped);
    await cmd({action:'clock',hour:6,minute:15});assert.ok((await state()).flags.clock_stopped);
    await aim('portrait',[-4.6,.05,-2]);assert.ok((await state()).flags.key);
    await aim('baul',[1.2,.05,-9]);assert.ok((await state()).flags.title);
    await aim('pact',[1.2,.05,-9.4]);await close();assert.ok((await state()).flags.pact);
  });
  await cmd({action:'grace',seconds:999});
  await check('three real eight-second quiet trials then seal and leave',async()=>{
    for(let i=0;i<3;i++){
      await aim('candle_'+i,[6.3+i*.7,.05,-8.5]);await waitFlag('trial_'+i);
    }
    assert.ok((await state()).flags.ritual_survived);await aim('altar',[7,.05,-7.9]);assert.ok((await state()).flags.sealed);
    await aim('gate',[0,.05,17.5]);assert.ok((await state()).cinematic.active);
  });
  await check('keeper cutscene pauses safely, completes and can replay without progress changes',async()=>{
    await page.waitForTimeout(1600);await screenshot('keeper-altar');
    await page.keyboard.press('Escape');await page.waitForTimeout(250);const before=(await state()).cinematic.time;
    await page.waitForTimeout(700);assert.equal((await state()).cinematic.time,before);await cmd({action:'resume'});
    await page.reload();await ready();await cmd({action:'continue'});
    assert.ok((await state()).cinematic.active,'Pending ending restarts safely after reload');assert.equal((await state()).cinematic.kind,'seal');
    await page.waitForFunction(()=>window.bulongTest.state.cinematic.time>22,{},{timeout:27000});await screenshot('keeper-breakfast');
    await page.waitForFunction(()=>window.bulongTest.state.modal==='ending',{},{timeout:18000});
    assert.equal((await state()).ending,'seal');const checkpoint=(await state()).checkpoint;
    await cmd({action:'replay',kind:'seal'});await page.keyboard.down('e');await page.waitForTimeout(2200);await page.keyboard.up('e');
    await page.waitForFunction(()=>!window.bulongTest.state.cinematic.active,{},{timeout:5000});
    assert.ok(!(await state()).cinematic.active);assert.deepEqual((await state()).checkpoint,checkpoint);
  });
  }
  await cmd({action:'branch'});assert.equal((await state()).route,'UNDECIDED');await cmd({action:'grace',seconds:999});
  await check('release fork commits to tape and gathers upstairs evidence',async()=>{
    await aim('radio',[-9,.05,6.2],1700);await close();assert.equal((await state()).route,'RELEASE');
    await aim('memory_photo',[-7,3.65,5.4]);await close();
    await aim('memory_letter',[-7.2,3.65,-5.1]);await close();
    await aim('tomas_clue',[7,3.65,-4.8]);await close();assert.equal((await state()).memories,3);
  });
  await check('real crawl hatch, forced crouch, movement and binding puzzle',async()=>{
    await aim('hatch_pantry',[-4.5,.05,-6.9]);await page.waitForTimeout(500);
    assert.ok((await state()).player[1]<-1.4);assert.ok((await state()).crouching);assert.equal((await state()).body_height,1);
    await page.keyboard.press('c');assert.ok((await state()).crouching);
    await cmd({action:'teleport',x:-4.5,y:-1.51,z:-8,yaw:0});await move('s',1000);
    assert.ok((await state()).player[2]>-7.2,'Crawlspace supports real low-height movement');
    await aim('binding_clock',[-4.5,-1.51,-8.6]);assert.ok(!(await state()).flags.binding_clock);
    await aim('binding_portrait',[-6.1,-1.51,-6]);
    await aim('binding_clock',[-4.5,-1.51,-8.6]);
    await aim('binding_bowl',[-1.4,-1.51,-8.6]);assert.ok((await state()).flags.bindings_done);
    await aim('hatch_exit_store',[0,-1.51,-8.1]);await page.waitForTimeout(450);assert.ok((await state()).player[1]>-.1);
    await screenshot('crawl-exit');
  });
  await check('release photograph, pact, lure and burning escape are not keeper chores',async()=>{
    await aim('sewing',[-3.4,3.65,-8.4]);await close();assert.ok((await state()).flags.photo_restored);
    await aim('baul',[1.2,.05,-9]);await aim('pact',[1.2,.05,-9.4]);await close();
    await aim('matches',[-7.4,.05,-7]);
    await aim('altar',[7,.05,-7.9]);assert.ok(!(await state()).flags.pact_burned,'Radio lure is required');
    await aim('radio',[-9,.05,6.2]);assert.ok((await state()).flags.lure_used);
    await aim('altar',[7,.05,-7.9]);await waitFlag('pact_burned');assert.equal((await state()).entity_state,'HUNT');
    assert.ok(!(await state()).flags.ritual_survived);assert.ok(!(await state()).flags.clock_stopped);
    await cmd({action:'teleport',x:0,y:.05,z:9.5,yaw:Math.PI});await walkUntil('w',()=>window.bulongTest.state.player[2]>17.1);
    assert.ok((await state()).player[2]>16.5);await aim('gate',[0,.05,17.5]);
    assert.equal((await state()).cinematic.kind,'break');await page.waitForTimeout(1300);await screenshot('burn-house');
    await page.waitForFunction(()=>window.bulongTest.state.cinematic.time>15,{},{timeout:20000});await screenshot('burn-name');
    await page.waitForFunction(()=>window.bulongTest.state.modal==='ending',{},{timeout:30000});assert.equal((await state()).ending,'break');
    assert.deepEqual((await state()).unlocked,process.env.RELEASE_ONLY?['break']:['seal','break']);
  });
  await check('room sweep, rendering budget and small bilingual touch layout',async()=>{
    await cmd({action:'branch'});await cmd({action:'grace',seconds:999});
    const rooms=[['foyer',0,.05,6],['sala',-6,.05,6.5],['dining',-6,.05,0],['kitchen',-9,.05,-8],['pantry',-4.5,.05,-7],['store',0,.05,-8],['altar',5,.05,-7],['family',-6,3.65,6.5],['guest',8.5,3.65,5.5],['wash',-9,3.65,0],['study',-5,3.65,0],['lola',-7,3.65,-6],['sewing',-3.3,3.65,-8],['tomas',7,3.65,-5]];
    for(const quality of ['low','high']){
      await cmd({action:'quality',value:quality});
      for(const [room,x,y,z] of rooms){
        await cmd({action:'teleport',x,y,z,yaw:0,pitch:-12});await page.waitForTimeout(1000);
        const s=await state();samples.push({room,quality,fps:s.fps,draws:s.draws,triangles:s.triangles});
        assert.ok(s.draws<300,`${room} ${quality}: ${s.draws} draws`);assert.ok(s.triangles<50000,`${room} ${quality}: ${s.triangles} triangles`);
        if(quality==='high')await screenshot('room-'+room);
      }
    }
    await cmd({action:'quality',value:'low'});await cmd({action:'language',value:'fil'});await page.setViewportSize({width:854,height:480});await page.waitForTimeout(700);await screenshot('fil-touch');
    const s=await state();assert.ok(s.touch);assert.equal(s.language,'fil');assert.equal(s.quality,'low');assert.ok(s.muted);
  });
  await check('fullscreen never captures cursor and resumes usable input',async()=>{
    await page.locator('#fullscreen').click();await page.waitForTimeout(600);assert.ok(await page.evaluate(()=>!!document.fullscreenElement));
    assert.ok((await state()).paused);await cmd({action:'resume'});assert.ok((await state()).controlled);
    await page.evaluate(()=>document.exitFullscreen());await page.waitForTimeout(400);assert.ok((await state()).paused);await cmd({action:'resume'});
    assert.equal(await page.evaluate(()=>document.pointerLockElement),null);
  });
  await check('no script or browser errors',async()=>assert.deepEqual(errors,[]));
}catch(e){report.push({status:'failed',error:e.stack,state:await state().catch(()=>null),errors});await screenshot('failure').catch(()=>{});console.error(e);process.exitCode=1;}
finally{writeFileSync(`build/qa/${name}-expansion-report.json`,JSON.stringify({report,samples,errors},null,2));await browser.close();}
