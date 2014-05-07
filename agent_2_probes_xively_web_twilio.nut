// Agent code
const html1 = @"<!DOCTYPE html>
<html lang=""en"">
    <head>
        <meta charset=""utf-8"">
        <meta http-equiv=""refresh"" content=""30"">
        <meta name=""viewport"" content=""width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"">
        <meta name=""apple-mobile-web-app-capable"" content=""yes"">
          
        <script src=""http://code.jquery.com/jquery-1.9.1.min.js""></script>
        <script src=""http://code.jquery.com/jquery-migrate-1.2.1.min.js""></script>
        <script src=""http://d2c5utp5fpfikz.cloudfront.net/2_3_1/js/bootstrap.min.js""></script>
        
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap.min.css"" rel=""stylesheet"">
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap-responsive.min.css"" rel=""stylesheet"">

        <title>impTherm X&sup2</title>
    </head>
    <body style=""background-color:#666666"">
        <div class='container'>
            <div class='well' style='max-width: 480px; margin: 0 auto 10px; text-align:center;'>
        
            <img src=""//cdn.shopify.com/s/files/1/0370/6457/files/red_black_logo_side_300x100.png?800"">
                
                <h2>impTherm X&sup2<h2>
                <h4>Dual probe thermocouple temperature monitor</h4>
                <h2>Probe 1: ";
const html2 = @"&degF</h2><h2>Probe 2: ";
const html3 = @"&degF</h2>
            <img src=""//cdn.shopify.com/s/files/1/0370/6457/files/built-for-imp_300px.png?801"">
            </div>
        </div>
    </body>
</html>";

APIKEY <- "YOUR API KEY GOES HERE";

Xively <- {};    // this makes a 'namespace'

class Xively.Client {
    ApiKey = null;
    triggers = [];

	constructor(apiKey) {
		this.ApiKey = apiKey;
	}
	
	/*****************************************
	 * method: PUT
	 * IN:
	 *   feed: a XivelyFeed we are pushing to
	 *   ApiKey: Your Xively API Key
	 * OUT:
	 *   HttpResponse object from Xively
	 *   200 and no body is success
	 *****************************************/
	function Put(feed){
		local url = "https://api.xively.com/v2/feeds/" + feed.FeedID + ".json";
		local headers = { "X-ApiKey" : ApiKey, "Content-Type":"application/json", "User-Agent" : "Xively-Imp-Lib/1.0" };
		local request = http.put(url, headers, feed.ToJson());

		return request.sendsync();
	}
	
	/*****************************************
	 * method: GET
	 * IN:
	 *   feed: a XivelyFeed we fulling from
	 *   ApiKey: Your Xively API Key
	 * OUT:
	 *   An updated XivelyFeed object on success
	 *   null on failure
	 *****************************************/
	function Get(feed){
		local url = "https://api.xively.com/v2/feeds/" + feed.FeedID + ".json";
		local headers = { "X-ApiKey" : ApiKey, "User-Agent" : "xively-Imp-Lib/1.0" };
		local request = http.get(url, headers);
		local response = request.sendsync();
		if(response.statuscode != 200) {
			server.log("error sending message: " + response.body);
			return null;
		}
	
		local channel = http.jsondecode(response.body);
		for (local i = 0; i < channel.datastreams.len(); i++)
		{
			for (local j = 0; j < feed.Channels.len(); j++)
			{
				if (channel.datastreams[i].id == feed.Channels[j].id)
				{
					feed.Channels[j].current_value = channel.datastreams[i].current_value;
					break;
				}
			}
		}
	
		return feed;
	}

}
    

class Xively.Feed{
    FeedID = null;
    Channels = null;
    
    constructor(feedID, channels)
    {
        this.FeedID = feedID;
        this.Channels = channels;
    }
    
    function GetFeedID() { return FeedID; }

    function ToJson()
    {
        local json = "{ \"datastreams\": [";
        for (local i = 0; i < this.Channels.len(); i++)
        {
            json += this.Channels[i].ToJson();
            if (i < this.Channels.len() - 1) json += ",";
        }
        json += "] }";
        return json;
    }
}

class Xively.Channel {
    id = null;
    current_value = null;
    mytag = "";
    
    constructor(_id)
    {
        this.id = _id;
    }
    
    function Set(value, tag) { 
    	this.current_value = value;
        this.mytag = tag;
    }
    
    function Get() { 
    	return this.current_value; 
    }
    
    function ToJson() { 
    	local json = http.jsonencode({id = this.id, current_value = this.current_value, tags = this.mytag});
        //server.log(json);
        return json;
    }
}

client <- Xively.Client(APIKEY);
probe1 <- "";
probe2 <- "";
device.on("Xively", function(v) {
    server.log("P1: " + v.probe1temp + " | P2: " + v.probe2temp);
    channel1 <- Xively.Channel("Probe_1");
    channel1.Set(v.probe1temp, "Probe #1");
    probe1 = v.probe1temp;
    channel2 <- Xively.Channel("Probe_2");
    channel2.Set(v.probe2temp, "Probe #2");
    probe2 = v.probe2temp;
    feed <- Xively.Feed("YOUR FEED ID GOES HERE", [channel1, channel2]);
    client.Put(feed);
});

const TWILIO_ACCOUNT_SID = "YOUR ACCOUNT SID"
const TWILIO_AUTH_TOKEN = "YOUR AUTH TOKEN"
const TWILIO_FROM_NUMBER = "+17175551212" // your phone no goes here
const TWILIO_TO_NUMBER = "+17175551212" // destination phone no

http.onrequest(function(request, response) { 
    if (request.body == "") {
        local html = format(html1 + ("%s", probe1) + html2 + ("%s", probe2) + html3);
        response.send(200, html);
    }
    else {
      try {
        local data = http.jsondecode(request.body);
        // make sure we got all the values we're expecting
        if ("trigger1min" in data) {
          server.log(data.trigger1min);
          device.send("Trigger1Min", data);
          response.send(200, "OK");
        } 
        else if ("trigger1max" in data) {
            server.log(data.trigger1max);
            device.send("Trigger1Max", data);
            response.send(200, "OK");        
        }
        else if ("trigger2min" in data) {
            server.log(data.trigger2min);
            device.send("Trigger2Min", data);
            response.send(200, "OK");
        }
        else if ("trigger2max" in data) {
            server.log(data.trigger2max);
            device.send("Trigger2Max", data);
            response.send(200, "OK");
        }
       else {
            response.send(500, "Missing Data in Body");
       }     
      }
      catch (ex) {
        response.send(500, "Internal Server Error: " + ex);
      }
    }
});
function send_sms(number, message) {
    local twilio_url = format("https://api.twilio.com/2010-04-01/Accounts/%s/SMS/Messages.json", TWILIO_ACCOUNT_SID);
    local auth = "Basic " + http.base64encode(TWILIO_ACCOUNT_SID+":"+TWILIO_AUTH_TOKEN);
    local body = http.urlencode({From=TWILIO_FROM_NUMBER, To=number, Body=message});
    local req = http.post(twilio_url, {Authorization=auth}, body);
    local res = req.sendsync();
    if(res.statuscode != 201) {
        server.log("error sending message: "+res.body);
    }
}

device.on("Probe1", function(v) {
    //send_sms(TWILIO_TO_NUMBER, "Probe 1: " + v);
});
device.on("Probe2", function(v) {
    //send_sms(TWILIO_TO_NUMBER, "Probe 2: " + v);
});
