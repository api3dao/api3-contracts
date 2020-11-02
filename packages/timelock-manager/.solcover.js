const util = require('util');
const child = require('child_process');
const exec = util.promisify(child.exec);

async function onCompileComplete(){
  await exec('cp -a ../api3-token/artifacts/. ./.coverage_artifacts/');
  await exec('cp -a ../api3-pool/artifacts/. ./.coverage_artifacts/');
}

module.exports = {
  onCompileComplete,
  mocha: {
    grep: '(test uses evm_setNextBlockTimestamp)',
    invert: true
  }
}