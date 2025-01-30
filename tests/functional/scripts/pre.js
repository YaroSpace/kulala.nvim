const randomDate = require('moment')().format('YYYY-MM-DD HH:mm:ss');
client.log({ randomDate });
request.variables.set('FOOBAZ', randomDate);
const url = new URL(request.url.tryGetSubstituted());
const method = request.method;
const params = new URLSearchParams(request.url.query);
request.variables.set('FOOBAX', "fuzzi");
client.log({ url, method, params });
