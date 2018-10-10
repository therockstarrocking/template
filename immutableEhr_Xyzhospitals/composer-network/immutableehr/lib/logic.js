
/*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

'use strict';

/**
 * Sample transaction
 * @param {pid.AddPID} tx
 * @transaction
*/

function AddPID(tx) {
    var NS = "pid";
    return getAssetRegistry('pid.HL7251_PID').then(function (ma) {
        return ma.exists(tx.Hl7PidFormat.MSH_PID)
            .then(function (check) {
                if (check) {
                    return ma.update(tx.Hl7PidFormat)
                }
                return ma.add(tx.Hl7PidFormat)
            })
    })

}





/**
 * 
 * @param {pv.AddPV1} tx
 * @transaction
 */
async function AddPV1(tx) {

    var NS = "pv";
    return getAssetRegistry(NS + '.HL725PV1').then(function (ca) {
        return ca.exists(tx.Hl7Pv1Format.MSH_PV1)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.Hl7Pv1Format)
                }
                return ca.add(tx.Hl7Pv1Format)
            })
    })

}

/**
 * adding sample transaction transaction
 * @param {pv.AddPV2} tx
 * @transaction
*/

async function AddPV2(tx) {

    var NS = "pv";
    return getAssetRegistry(NS + '.HL725PV2').then(function (ca) {
        return ca.exists(tx.Hl7Pv2Format.MSH_PV2)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.Hl7Pv2Format)
                }
                return ca.add(tx.Hl7Pv2Format)
            })
    })

}

/**
 * adding sample transaction transaction
 * @param {iehr.AddMSH} tx
 * @transaction
*/

async function AddMSH(tx) {
    var NS = "iehr";
    return getAssetRegistry(NS + '.HL7251_MSH').then(function (ca) {
        return ca.exists(tx.Hl7MshFormat.MSHKEY)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.Hl7MshFormat)
                }
                let factory = getFactory();
                let basicEvent = factory.newEvent('iehr', 'mshcreated');
                basicEvent.id = tx.Hl7MshFormat.MSHKEY;
                emit(basicEvent);
                return ca.add(tx.Hl7MshFormat)
            })
    })
}


/**
 * adding sample transaction transaction
 * @param {obr.AddOBR} tx  
 * @transaction
*/

async function AddOBR(tx) {

    var NS = "obr";
    return getAssetRegistry(NS + '.HL7251_OBR').then(function (ca) {
        return ca.exists(tx.Hl7obrFormat.MSH_OBR)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.Hl7obrFormat)
                }
                return ca.add(tx.Hl7obrFormat)
            })
    })
}

/**
 * adding sample transaction transaction
 * @param {obx.AddOBX} tx
 * @transaction
*/
async function AddOBX(tx) {
    var NS = "obx";
    return getAssetRegistry(NS + '.HL7251_OBX').then(function (ca) {
        return ca.exists(tx.Hl7obxFormat.MSH_OBX)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.Hl7obxFormat)
                }
                return ca.add(tx.Hl7obxFormat)
            })
    })
}


/**
 * adding sample transaction transaction
 * @param {pd.AddPD} tx
 * @transaction
*/
async function AddPD(tx) {
    var NS = "pd";
    return getAssetRegistry(NS + '.HL7251_PD').then(function (ca) {
        return ca.exists(tx.Hl7PdFormat.MSH_PD)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.Hl7PdFormat)
                }
                return ca.add(tx.Hl7PdFormat)
            })
    })
}

/**
 * adding sample transaction transaction
 * @param {orc.AddORC} tx
 * @transaction
*/

async function AddORC(tx) {
    var NS = "orc";
    return getAssetRegistry(NS + '.HL7251_ORC').then(function (ca) {
        return ca.exists(tx.Hl7orcformat.MSH_ORC)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.Hl7orcformat)
                }
                return ca.add(tx.Hl7orcformat)
            })
    })
}

/**
 * adding sample transaction transaction
 * @param {Destinationorg.Adddestorg} tx
 * @transaction
*/

async function Adddestorg(tx) {
    var NS = "Destinationorg";
    var deskey=tx.MSHKEY+""+"_"+tx.desOrganizationID 
    let factory = getFactory();
    var dorg = factory.newResource('Destinationorg','Destorg',deskey); 
    dorg.MSHKEY=tx.MSHKEY;
    dorg.desOrganizationID=tx.desOrganizationID
    return getAssetRegistry(NS + '.Destorg').then(function (ca) {
        return ca.exists(deskey)
            .then(function (check) {
                if (check) {
                    return ca.update(dorg)
                }
		let factory = getFactory();
                let basicEvent = factory.newEvent('iehr', 'destorgwithmsh');
                basicEvent.mshkey  = tx.MSHKEY;
		basicEvent.destkey = tx.desOrganizationID;
                emit(basicEvent);		
                return ca.add(dorg)
            })
    })
}



/**
 * adding sample transaction transaction
 * @param {orgparticipant.Addparticipant} tx
 * @transaction
*/

async function Addparticipant(tx) {
    var NS = "orgparticipant";
    return getParticipantRegistry(NS + '.hie').then(function (ca) {
        return ca.exists(tx.user.OrganizationID)
            .then(function (check) {
                if (check) {
                    return ca.update(tx.user)
                }
                return ca.add(tx.user)
            })
    })
}




/**
 * adding sample transaction transaction
 * @param {sourceorg.Addsourceorg} tx
 * @transaction
*/

async function Addsourceorg(tx) {
    var NS = "sourceorg";
    var sourcekey=tx.MSHKEY+""+"_"+tx.sourOrganizationID 
    let factory = getFactory();
    var sorg = factory.newResource('sourceorg','Sourceorg',sourcekey); 
    sorg.MSHKEY=tx.MSHKEY;
    sorg.sourOrganizationID=tx.sourOrganizationID
    return getAssetRegistry(NS + '.Sourceorg').then(function (ca) {
        return ca.exists(sourcekey)
            .then(function (check) {
                if (check) {
                    return ca.update(sorg)
                }
                return ca.add(sorg)
            })
    })
}





