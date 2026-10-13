// Bootstrap through Kuma's authenticated Socket.IO API; never modify its database.
// This runs once. Later UI changes remain authoritative for monitors and pages.
const fs = require('node:fs');
const { io } = require('/app/node_modules/socket.io-client');
const credentials = JSON.parse(fs.readFileSync('/run/secrets/kuma-admin.json', 'utf8'));
const inventory = JSON.parse(fs.readFileSync('/bootstrap/monitors.json', 'utf8'));
const socket = io('http://127.0.0.1:3001', { transports: ['websocket'], reconnection: false, timeout: 30000 });
let monitors = {};
socket.on('monitorList', value => { monitors = value; });
function call(event, ...args) {
    return new Promise((resolve, reject) => {
        socket.timeout(30000).emit(event, ...args, (error, result) => {
            if (error) return reject(error);
            if (result && result.ok === false) return reject(new Error(event + ': ' + result.msg));
            resolve(result);
        });
    });
}
(async () => {
    await new Promise((resolve, reject) => { socket.once('connect', resolve); socket.once('connect_error', reject); });
    if (await call('needSetup')) await call('setup', credentials.username, credentials.password);
    await call('login', { ...credentials, token: '' });
    await call('getMonitorList');
    const group = { name: 'Private apps on igloo', monitorList: [] };
    for (const app of inventory) {
        let existing = Object.values(monitors).find(monitor => monitor.url === app.url);
        let id = existing?.id;
        if (!id) {
            const result = await call('add', {
                ...app, type: 'http', method: 'GET', interval: 60, retryInterval: 30,
                timeout: 15, maxretries: 2, maxredirects: 5, upsideDown: false,
                ignoreTls: false, expiryNotification: false, active: true,
                accepted_statuscodes: ['200-299', '300-399'], notificationIDList: {},
                conditions: [], description: 'Checks public hostname, trusted TLS, reverse proxy, and application response over Tailscale.'
            });
            id = result.monitorID;
        }
        group.monitorList.push({ id, sendUrl: true, url: app.url });
    }
    let page;
    try { page = await call('getStatusPage', 'apps'); }
    catch (error) {
        if (!error.message.includes('No slug?')) throw error;
        await call('addStatusPage', 'Glowbug Apps', 'apps');
        page = await call('getStatusPage', 'apps');
    }
    const config = {
        ...page.config, slug: 'apps', title: 'Glowbug Apps', theme: 'auto',
        description: 'Private services on appnv / igloo. Monitored independently from ktz-cloud every minute. Tailscale required.',
        footerText: 'Checks include DNS, trusted HTTPS, and application responses. No notifications are configured.',
        domainNameList: ['status.apps.glowbug.io'], showCertificateExpiry: true,
        showPoweredBy: true, showTags: false, autoRefreshInterval: 60,
        analyticsType: null, analyticsId: null, analyticsScriptUrl: null,
        customCSS: '', showOnlyLastHeartbeat: false
    };
    await call('saveStatusPage', 'apps', config, config.icon || '', [group]);
    const settings = await call('getSettings');
    await call('setSettings', { ...settings.data, entryPage: 'statusPage-apps', keepDataPeriodDays: 90 }, null);
    fs.writeFileSync('/app/data/.infra-bootstrap-complete', new Date().toISOString() + '\n', { mode: 0o600 });
    console.log('Configured ' + inventory.length + ' monitors and the private status page. Notifications disabled.');
    socket.disconnect();
})().catch(error => { console.error(error.message); socket.disconnect(); process.exitCode = 1; });
