// Original code-drawn icon; no external raster assets or dependencies.
const fs = require('fs');
const path = require('path');
const size = 128, pixels = Buffer.alloc(size * size * 4);
function inside(x, y, poly) {
  let c = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[i], b = poly[j];
    if (((a[1] > y) !== (b[1] > y)) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c;
  }
  return c;
}
function color(x, y) {
  let col = [8, 29, 43, 255];
  if (Math.hypot(x - 64, y - 64) > 63) return [0,0,0,0];
  const ring = Math.hypot(x - 64, y - 64);
  if (ring > 53 && ring < 54.5) col = [51, 86, 92, 255];
  if (inside(x,y,[[49,36],[12,20],[12,54]]) || inside(x,y,[[79,36],[116,20],[116,54]])) col=[89,88,67,255];
  if (inside(x,y,[[55,43],[73,43],[81,98],[47,98]])) col=[229,188,119,255];
  if (inside(x,y,[[58,47],[70,47],[76,94],[52,94]])) col=[37,64,74,255];
  if (x>50 && x<78 && y>27 && y<44) col=[233,195,129,255];
  if (x>55 && x<73 && y>31 && y<40) col=[255,225,163,255];
  if (inside(x,y,[[46,27],[64,13],[82,27]])) col=[229,188,119,255];
  if (x>59 && x<69 && y>61 && y<74) col=[236,199,130,255];
  if (y>98 && y<103 && x>28 && x<100) col=[229,188,119,255];
  return col;
}
for (let y=0;y<size;y++) for(let x=0;x<size;x++) {
  const sum=[0,0,0,0];
  for(let sy=0;sy<4;sy++) for(let sx=0;sx<4;sx++) {
    const c=color(x+(sx+.5)/4,y+(sy+.5)/4);
    for(let k=0;k<4;k++) sum[k]+=c[k]/16;
  }
  const off=((size-1-y)*size+x)*4;
  pixels[off]=sum[2];pixels[off+1]=sum[1];pixels[off+2]=sum[0];pixels[off+3]=sum[3];
}
const dib=Buffer.alloc(40);dib.writeUInt32LE(40);dib.writeInt32LE(size,4);dib.writeInt32LE(size*2,8);dib.writeUInt16LE(1,12);dib.writeUInt16LE(32,14);dib.writeUInt32LE(pixels.length,20);
const mask=Buffer.alloc(size*size/8);
const image=Buffer.concat([dib,pixels,mask]);
const header=Buffer.alloc(22);header.writeUInt16LE(1,2);header.writeUInt16LE(1,4);header[6]=size;header[7]=size;header.writeUInt16LE(1,10);header.writeUInt16LE(32,12);header.writeUInt32LE(image.length,14);header.writeUInt32LE(22,18);
fs.writeFileSync(path.join(__dirname,'icon.ico'),Buffer.concat([header,image]));
