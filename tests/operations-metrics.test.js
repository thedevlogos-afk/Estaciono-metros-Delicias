import test from 'node:test';
import assert from 'node:assert/strict';
import {operationMetrics} from '../assets/operations-metrics.js';
test('sin registros no inventa promedio de atención',()=>{assert.equal(operationMetrics().averageMinutes,null);});
test('calcula tiempos válidos y separa pendientes de reiteraciones',()=>{const rows=[{parquimetro_id:'A',estatus:'pendiente',creado:'2026-11-16T10:00:00Z'},{parquimetro_id:'A',creado:'2026-11-16T10:00:00Z',verificado:'2026-11-16T10:30:00Z'},{parquimetro_id:'B',creado:'2026-11-16T10:00:00Z',verificado:'2026-11-16T09:00:00Z'}];const result=operationMetrics(rows);assert.equal(result.averageMinutes,30);assert.equal(result.pending,1);assert.deepEqual(result.recurring,[['A',2]]);});
