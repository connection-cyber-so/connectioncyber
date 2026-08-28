import { createHash } from 'node:crypto';

const hash=(value)=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
export class PeripheralSimulator{
  #seen=new Map();
  constructor({scaleWeight=1.25,tefOutcome='approved'}={}){this.scaleWeight=scaleWeight;this.tefOutcome=tefOutcome}
  execute(command){
    if(this.#seen.has(command.idempotencyKey))return{...this.#seen.get(command.idempotencyKey),replayed:true};
    let result;
    switch(command.type){
      case'print.execute':result={status:'succeeded',code:'PRINTED',documentHash:command.payload.documentHash,copies:command.payload.copies??1};break;
      case'scale.read':result={status:'succeeded',code:'STABLE_WEIGHT',weight:this.scaleWeight,unit:'kg',stable:true};break;
      case'cash_drawer.open':result={status:'succeeded',code:'DRAWER_PULSE_SENT'};break;
      case'tef.execute':result=this.tefOutcome==='timeout'?{status:'manual_review',code:'TEF_TIMEOUT_UNKNOWN'}:{status:'succeeded',code:'TEF_APPROVED',nsu:'SIMULATED-NSU',authorization:'SIMULATED-AUTH'};break;
      default:result={status:'failed',code:'UNSUPPORTED_COMMAND'};
    }
    const deterministic={...result,resultHash:hash({idempotencyKey:command.idempotencyKey,...result})};this.#seen.set(command.idempotencyKey,deterministic);return{...deterministic,replayed:false};
  }
}
