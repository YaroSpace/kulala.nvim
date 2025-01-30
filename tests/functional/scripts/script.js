const randomDate = require('moment')().format('YYYY-MM-DD HH:mm:ss');
client.global.set('RANDOM_DATE', randomDate);
client.log(randomDate);
