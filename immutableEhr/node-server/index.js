'use strict';
var glob = require("glob");
var fs = require("fs");
var express =  require("express");
var bodyParser = require("body-parser");
var request = require("request");
var chokidar = require('chokidar');
const replace = require('replace-in-file');
const loading =  require('loading-cli');
var W3CWebSocket = require('websocket').w3cwebsocket;
var events = require('events')


var client = new W3CWebSocket('ws://192.168.1.158:3002/', 'echo-protocol');
const load = loading('loading...')
var scount = 0;
var fcount = 0;
//load.frame(["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"]);
//load.frame([".", "o", "O", "°", "O", "o", "."]);
//load.frame(["⊶", "⊷"]);
//load.frame(["◐", "◓", "◑", "◒"]);
//load.frame(["◰", "◳", "◲", "◱"]);
load.frame(["˙˙"," :","..",": "]);
//load.frame(["‾"," |","_","| "]);
load.interval = 300;
load.color = 'blue';

var app = express();
client.onerror = function() {
    console.log('Connection Error');
};

client.onopen = function() {
    console.log('WebSocket Client Connected');
 
    // function sendNumber() {
    //     if (client.readyState === client.OPEN) {
    //         var number = Math.round(Math.random() * 0xFFFFFF);
    //         client.send(number.toString());
    //         setTimeout(sendNumber, 1000);
    //     }
    // }
    // sendNumber();  
};
 
client.onclose = function() {
    console.log('echo-protocol Client Closed');
};
 
client.onmessage = function(e) {
    if (typeof e.data === 'string') {
       var data=JSON.parse(e.data)
        //console.log(data.$class)
        var mshkey=data['mshkey']
        if ( mshkey == undefined){
            return;
        }
        var index=100
        console.log("**************************************",mshkey)
        var url='http://192.168.1.158:3002/api/HL7251_MSH/'+mshkey
        console.log(url)
        readingmessages(url,mshkey,index,function(msh, filename, index){
            console.log("success file download with name ",filename)
        })
    }
};

var watcher = chokidar.watch('./transactions', {
  ignored: /[\/\\]\./, persistent: true
});
console.time("nstart");
var log = console.log.bind(console);

watcher
  .on('add', function(path) { 
    //load.start('File '+path+' has been added and Processing')
   // setTimeout(function(){
   
    fs.readFile(path, 'utf8', function (err, data) {
        if(err) {
            console.log("cannot read the file, something goes wrong with the file", err);
        }
        var obj = JSON.parse(data);
        var apiCall = obj.$class;
        var index = apiCall.split(".");
        console.log(apiCall,index[1]);
        if(index[1] == undefined || index[1] ==""){
            return;
        }
        postRequest(index[1],obj,path);
       
        
        //console.log(file,obj);
    });

//},3002)
})
function postRequest(api,obj,path){
    console.log(api)
    request.post({
        "headers": { "content-type": "application/json" },
        "url": "http://192.168.1.158:3002/api/"+api,
        "body": JSON.stringify(obj)
    }, (error, response, body) => {
        if( error != null){
        if(error.code === 'ESOCKET' || error.code === 'ESOCKETTIMEDOUT' || error.code === 'ECONNRESET'){
            console.log(error.code)
            postRequest(api,obj,path);
            console.log("error", error)
            return;
        }
    }
        
        //console.log(" response:", response);
        console,log(" body: ",body)
        var respBody = JSON.parse(body);
        if(respBody.error){
            fcount++;
            let newp = path.split('/');
            let newPath = "UnsuccTransactions/"+newp[1];
            fs.rename(path, newPath, function (err) {
                if (err) {
                    if (err.code === 'EXDEV') {
                        copy();
                    } else {
                        console.log("error",err)
                    }
                }
                console.timeEnd("pstart");
            });
        }else{
            scount++;
            let newp = path.split('/');
            let newPath = "ProcessedTransactions/"+newp[1];
            fs.rename(path, newPath, function (err) {
                if (err) {
                    if (err.code === 'EXDEV') {
                        copy();
                    } else {
                        console.log("error",err)
                    }
                }
                
            });
            console.timeEnd("pstart");
        }
        /*console.dir(JSON.parse(body));
       // load.stop();
        if(body){
            
        }*/
    });
    
}
setTimeout(function(){
    stop();
},2000)
function stop(){
    fs.readdir('./transactions', function(err, files) {
        //console.log("stop method called")
        if (err) {   
        } else {
            if (!files.length) {
                //watcher.close()
                console.log("folder Empty");
                console.timeEnd("nstart");
                console.time("nstart");
                console.log("success count:",scount);
                console.log("failure count:",fcount);
                setTimeout(function(){
                    stop();
                },2000)
            }
            else{
                setTimeout(function(){
                    stop();
                },500)
            }
        }
    });
}

function copy() {
    var readStream = fs.createReadStream(path);
    var writeStream = fs.createWriteStream(newPath);

    readStream.on('error');
    writeStream.on('error');

    readStream.on('close', function () {
        fs.unlink(path);
    });

    readStream.pipe(writeStream);
}


/*glob("transactions/*.json", function(err, files) {
    if(err) {
        console.log("cannot read the folder, something goes wrong with glob", err);
    }
    var matters = [];
    files.forEach(function(file) {
    fs.readFile(file, 'utf8', function (err, data) {
        if(err) {
            console.log("cannot read the file, something goes wrong with the file", err);
        }
        var obj = JSON.parse(data);
        var apiCall = obj.$class=88
        var index = apiCall.spy6;(".");
        console.log(apiCall,index[3]);
        if(index[3] == undefined || index[3] ==""){
            return;
        }
        Request.post({
            "headers": { "content-type": "application/json" },
            "url": "http://192.168.1.158:3002/api/"+index[3]+"",
            "body": JSON.stringify(obj)
        }, (error, response, body) => {
            if(error) {
                return console.dir(error);
            }
            console.dir(JSON.parse(body));
        });
        console.log(file,obj);
        
        });
    });
});*/
/*var trnames = ["etr1","etr2"];
Request.get("http://192.168.1.158:3002/api/org.examples.mynetwork.Trader", (error, response, body) => {
    if(error) {
        return console.dir(error);
    }
    var data = JSON.parse(body)
    console.dir(data);
    
    for(let i=0;i<data.length;i++){
        var count = 0;
        for(var j=0;j<trnames.length;j++){
            if(trnames[j] == data[i].tradeId){
                count = 1;
            }
        }
        if(count == 0){
            trnames[trnames.length]=data[i].tradeId;
            let filename = "trader_"+data[i].tradeId;
            //data[i].$class = data[i].$class.replace(/exapmles/g,'example')
            let data1 = JSON.stringify(data[i],null,2);
            data1 = data1.replace(/examples/g,'example')
            data1 = data1.replace(/[[]]/g,' ')
            //console.log(dt);
            fs.writeFile('transactions/'+filename+"", data1, (err) => {
                if (err) throw err;
                console.log("The ",filename," file was succesfully saved!");
                /*const options = {
                    files: 'needToProcess/'+filename+"",
                    from: /examples/g,
                    to: 'example',
                };
                var changes = replace.sync(options);
                console.log('Modified files:', changes.join(', '));*/
            //});
        //}
    //}
    //var filename = "tr3"

//})


app.use(function (req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    next();
});

app.get('/getbyorgname/:orgname/:starttime/:endtime', function (req, res) {
	

    var value = req.params.orgname
    var starttime = req.params.starttime;
    var endtime = req.params.endtime;
	console.log(starttime);
    var url = "http://192.168.1.158:3002/api/queries/seletallmshwithorgid?OrganizationID="+ value
    readbyorgid(url, starttime, endtime,function (data,coun,val) {
	console.log(coun,val)
	if(coun === ((7*val))){
		console.log(data)

        	res.send(data)
	}
    })
})


async function readbyorgid(url2, starttime, endtime, backto) {
	console.log(starttime)
	console.log(endtime)
    var object = {};
    var count = 0;
    request({
        url: url2,
        method: "GET",
        timeout: 1000,
        followRedirect: true,
        maxRedirects: 10
    }, function (error, response, body) {

        if (!error && response.statusCode == 200 && body != null && body != '[]' && body != undefined) {
            var temp = JSON.parse(body);
            var value = Object.keys(temp).length
            // .log(value)
            for (var i in temp) {
                console.log("i = ", i)
                if (starttime != "null" && endtime != "null") {
                    var url = "http://192.168.1.158:3002/api/queries/selectmessagetimeinterval?starttime=" + starttime + "&endtime=" + endtime + "&MSHKEY=" + temp[i].MSHKEY

                    readingmessages(url, temp[i].MSHKEY, i, function (msh, filename, index) {
                        console.log("count",filename)
                        if(filename == ""){
                            ++count;
			backto(object,count,value);
                        }else{
			    count++ ;

                            if (object[msh] == undefined) {
                                object[msh] = [];
                            }
                            object[msh].push(filename);
				backto(object,count,value);
                        }
                    });
                } else if (starttime != "null" && (endtime == "null" || endtime == undefined)) {
                    var url = "http://192.168.1.158:3002/api/queries/selectmessagesgrttime?starttime=" + starttime + "&MSHKEY=" + temp[i].MSHKEY
                    readingmessages(url, temp[i].MSHKEY, i, function (msh, filename, index) {
                        console.log("count", count,filename)
                        if(filename == ""){
                            ++count;
		backto(object,count,value);
                        }else{ 
			    count++ ;

                            if (object[msh] == undefined) {
                                object[msh] = [];
                            }
                            object[msh].push(filename);
				backto(object,count,value);
                        }
                    });
                } else if (endtime != "null" && (starttime == "null" || starttime == undefined)) {
                    var url = "http://192.168.1.158:3002/api/queries/selectmessagelesstime?endtime=" + endtime + "&MSHKEY=" + temp[i].MSHKEY
                    readingmessages(url, temp[i].MSHKEY);
                } else {
                    console.log('date must select' + error);
                }

            }
        } else {
            if(error.code === 'ESOCKET' || error.code === 'ESOCKETTIMEDOUT'){
                console.log(error.code)
                readbyorgid(url2, starttime, endtime, backto)
            }
            console.log("error", error)
        }
    });
}

function readingmessages(url2, mshkey, index, cp) {
    var headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    var count;
    request({
        url: url2,
        method: "GET",
        timeout: index,
        followRedirect: true,
        maxRedirects: 10
    }, async function (error, response, body) {
        console.log("-----------------------------------------------------",body,url2,mshkey,index,cp)
        if (!error && response.statusCode == 200 && body != null && body != '[]' && body != undefined && body != []) {
            var temp = JSON.parse(body);
            console.log(temp)
            fs.writeFile("GeneratedFIles" + "/" + mshkey + ".json", body, function (err) {
                if (err) throw err;
                console.log('Saved! with', mshkey + ".json");
            });

            readingfile("http://192.168.1.158:3002/api/queries/pidmsh?MSHKEY=" + mshkey, mshkey + "_PID.json", "GeneratedFIles", function (results) {
                if (results == "") {
                    cp(mshkey, "")
                } else {
                    cp(mshkey, results, index)
                }
            })
            readingfile("http://192.168.1.158:3002/api/queries/obrmsh?MSHKEY=" + mshkey, mshkey + "_OBR.json", "GeneratedFIles", function (results) {
                if (results == "") { cp(mshkey, "") } else { cp(mshkey, results, index) }
            });
            readingfile("http://192.168.1.158:3002/api/queries/obxmsh?MSHKEY=" + mshkey, mshkey + "_OBX.json", "GeneratedFIles", function (results) {
                if (results == "") { cp(mshkey, "") } else { cp(mshkey, results, index) }
            })
            readingfile("http://192.168.1.158:3002/api/queries/pv1msh?MSHKEY=" + mshkey, mshkey + "_PV1.json", "GeneratedFIles", function (results) {
                if (results == "") { cp(mshkey, "") } else { cp(mshkey, results, index) }
            })
            readingfile("http://192.168.1.158:3002/api/queries/orcmsh?MSHKEY=" + mshkey, mshkey + "_ORC.json", "GeneratedFIles", function (results) {
                if (results == "") { cp(mshkey, "") } else { cp(mshkey, results, index) }
            })
            readingfile("http://192.168.1.158:3002/api/queries/pdmsh?MSHKEY=" + mshkey, mshkey + "_PD.json", "GeneratedFIles", function (results) {
                console.log("iam from messages key dont distrubte" + results)
                if (results == "") { cp(mshkey, "") } else { cp(mshkey, results, index) }
            })
            readingfile("http://192.168.1.158:3002/api/queries/pv2msh?MSHKEY=" + mshkey, mshkey + "_PV2.json", "GeneratedFIles", function (results) {
                if (results == "") { cp(mshkey, "") } else { cp(mshkey, results, index) }
            })
        } else {
            if(body.error && body.error.statusCode == 404 && index < 10000){
                setTimeout(function(){
                    readingmessages(url2,mshkey,index*10,cp);
                })
            }
            if(error.code && error.code === 'ESOCKET' || error.code === 'ESOCKETTIMEDOUT' || error ==='ESOCKETTIMEDOUT' && index < 10000){
                readingmessages(url2,mshkey,index*10,cp);
            }
            console.log('selected org did not have any messages in blockchain' + error);
        }

    });
}

function readingfile(url1, filename, directory, cp) {
    var headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    request({
        url: url1,
        method: "GET",
        followRedirect: true,
    }, function (error, response, data) {
        this.urlsub = url1;
        this.filename = filename
        if (!error && response.statusCode == 200 && data != null && data != '[]' && data != undefined) {
            var temp1 = JSON.parse(data)
            var txt = JSON.stringify(temp1);
            fs.writeFile(directory + "/" + filename, txt, function (err) {
                if (err) throw err;
                console.log('Saved! with', filename);
                cp(filename)
            });
        } else {
            if (data == [] || data == undefined || error == null) {
                console.log("their is no value for specified url")
                cp("")
            } else {
                fs.writeFile(directory + "_logs" + "/" + "log_" + filename, error, function (err) {
                    if (err) {
                         console.log(err)
                        }
                    cp("")
                    console.log('see in the log file in the directory', directory + "_logs");
                });
            }
        }

    })

}


