import axios from 'axios';
import { SQLColumn, SQLItem } from './types';
import { getCapabilityName } from './utils';


export type DashboardConfiguration = {
    componentName: string,
    componentDisplayName: string,
    folderUid: string,
    tableName: string,
    columns: SQLItem
}


const BASE_URL = process.env['GRAFANA_ENDPOINT'];
const TOKEN = process.env['GRAFANA_TOKEN'];
const headers = {
    Authorization: `Bearer ${TOKEN}`,
    'Content-Type': 'application/json'
};

const datasource = {
    type: 'mssql',
    uid: process.env['GRAFANA_DATASOURCE_UID']
};

export async function createFolder(modelDisplayName: string): Promise<string> {
    const res = await axios.post<any>(`${BASE_URL}/api/folders`, {
        title: modelDisplayName
    }, {
        headers
    });
    return res.data['uid'];
}

/**
 * Generates the raw sql query based on the table name and the selection
 */
function _sanitizeQueries(panels: any[], config: DashboardConfiguration, props?: boolean): any[] {
    return panels.map(panel => ({
        ...panel,
        targets: [
            {
                ...panel.targets[0],
                rawSql: `SELECT\n  $__timeEpoch(ts),\n ${panel.targets[0].selects.join(',\n')}\nFROM\n  dbo.${config.tableName}${props ? '_props' : ''}\nWHERE\n  deviceId = '\${deviceId}'`
            }
        ]
    }))
}

function _reduceColumns(panels: any[], telemetry: SQLColumn, idx: number) {
    const gridPos = {
        h: 8,
        w: 12,
        x: idx % 2 === 0 ? 0 : 12,
        y: ((idx === 0) ? 0 : (idx % 2 === 0 ? (idx * 4) : ((idx - 1) * 4))) + 1 // add size for rows
    };
    // check if it's a complex value
    if (telemetry.parentName && telemetry.parentDisplayName) {
        const displayNameSegments = telemetry.displayName.split('.');
        const displayName = displayNameSegments[displayNameSegments.length - 1];

        const parent = panels.find(p => p.tags.includes(telemetry.parentName))
        if (parent) {
            parent.targets[0].selects.push(`[${telemetry.name}] as [${displayName}]`)
        }
        else {
            if (telemetry.isLocation) {
                panels.push({
                    datasource,
                    gridPos,
                    targets: [{
                        datasource,
                        format: 'time_series',
                        selects: [`[${telemetry.name}] as [${displayName}]`]
                    }],
                    options: {
                        layers: [
                            {
                                config: {
                                    showLegend: true,
                                    style: {
                                        color: {
                                            fixed: 'dark-green'
                                        },
                                        opacity: 0.4,
                                        rotation: {
                                            fixed: 0,
                                            max: 360,
                                            min: -360,
                                            mode: 'mod'
                                        },
                                        size: {
                                            fixed: 5,
                                            max: 15,
                                            min: 2
                                        },
                                        symbol: {
                                            fixed: 'img/icons/marker/circle.svg',
                                            mode: 'fixed'
                                        },
                                        textConfig: {
                                            fontSize: 12,
                                            offsetX: 0,
                                            offsetY: 0,
                                            textAlign: 'center',
                                            textBaseline: 'middle'
                                        }
                                    }
                                },
                                location: {
                                    latitude: 'Latitude',
                                    longitude: 'Longitude',
                                    mode: 'coords'
                                },
                                name: '${deviceId}',
                                tooltip: true,
                                type: 'markers'
                            }
                        ]
                    },
                    title: telemetry.parentDisplayName,
                    type: 'geomap',
                    tags: [telemetry.parentName]
                })
            }
            panels.push({
                datasource,
                gridPos,
                targets: [{
                    datasource,
                    format: 'time_series',
                    selects: [`[${telemetry.name}] as [${displayName}]`]
                }],
                title: telemetry.parentDisplayName,
                type: 'timeseries',
                tags: [telemetry.parentName]
            })
        }
        return panels;
    }
    panels.push({
        datasource,
        gridPos,
        targets: [{
            datasource,
            format: 'time_series',
            selects: [`[${telemetry.name}] as [${telemetry.displayName}]`]
        }],
        title: telemetry.displayName,
        type: 'timeseries',
        tags: [telemetry.name]
    })
    return panels;
}

function _createProperties(config: DashboardConfiguration, expanded: boolean) {
    return config.columns.properties.reduce<any>((row, column, idx) => {
        const gridPos = {
            h: 8,
            w: 12,
            x: idx % 2 === 0 ? 0 : 12,
            y: ((idx === 0) ? 0 : (idx % 2 === 0 ? (idx * 4) : ((idx - 1) * 4))) + (expanded ? 2 : 0) // add size for rows
        };
        row.panels = [...row.panels, {
            datasource,
            gridPos,
            options: {
                content: `<div style='display: flex; flex-direction: column; justify-content: center; align-items: center; height: 100%'>\n <h1>\${${getCapabilityName(column.name)}}</h1>\n  <p>\${${getCapabilityName(column.name)}_lasttime}</p>\n </div>`,
                mode: 'html'
            },
            targets: [],
            title: column.displayName,
            type: 'text'
        }];

        row.list = [...row.list, {
            datasource,
            hide: 2,
            includeAll: false,
            label: 'Value',
            multi: false,
            name: getCapabilityName(column.name),
            options: [],
            query: `select t.[${column.name}] from dbo.${config.tableName}_props t inner join (\nselect deviceId,max([ts]) as maxdate from dbo.${config.tableName}_props where deviceId = '\${deviceId}' group by [deviceId]\n) tm on t.deviceId=tm.deviceId and t.ts=tm.maxdate`,
            refresh: 2,
            skipUrlSync: false,
            sort: 0,
            type: 'query'
        },
        {
            datasource,
            hide: 2,
            includeAll: false,
            label: 'LastTime',
            multi: false,
            name: `${getCapabilityName(column.name)}_lasttime`,
            options: [],
            query: `select CONVERT(VARCHAR(MAX),t.[ts],9) from dbo.${config.tableName}_props t inner join (\nselect deviceId,max([ts]) as maxdate from dbo.${config.tableName}_props where deviceId = '\${deviceId}' group by [deviceId]\n) tm on t.deviceId=tm.deviceId and t.ts=tm.maxdate`,
            refresh: 2,
            skipUrlSync: false,
            sort: 0,
            type: 'query'
        }];
        return row;
    }, {
        panels: [],
        list: []
    }
    )
}

function _getDeviceIdVariable(tableName: string) {
    return {
        datasource,
        name: 'deviceId',
        label: 'Device',
        definition: `select [deviceId] from dbo.${tableName}`,
        query: `select [deviceId] from dbo.${tableName}`,
        includeAll: false, // Include the "show all devices" option
        multi: false, // enable multiple selection
        refresh: 2, // reload variables at time change
        type: 'query',
        options: [],
        regex: '',
        skipUrlSync: false,
        sort: 0,
        hide: 0
    }
};

export async function createComponentDashboard(config: DashboardConfiguration): Promise<string> {
    const propertiesCollapsed = config.columns.telemetry.length > 0;
    const telemetriesCollapsed = !propertiesCollapsed;
    const propertiesRows = _createProperties(config, !propertiesCollapsed);
    let res = await axios.post<any>(`${BASE_URL}/api/dashboards/db`, {
        dashboard: {
            title: config.componentDisplayName || 'Default',
            tags: [config.componentName || 'default'],
            panels: [
                {
                    gridPos: {
                        h: 1,
                        w: 24,
                        x: 0,
                        y: 0
                    },
                    type: 'row',
                    title: 'Telemetry',
                    panels: [],
                    collapsed: telemetriesCollapsed
                },
                ..._sanitizeQueries(config.columns.telemetry.reduce(_reduceColumns, []), config),
                {
                    gridPos: {
                        h: 1,
                        w: 24,
                        x: 0,
                        y: (config.columns.telemetry.length * 8) + 1
                    },
                    type: 'row',
                    title: 'Properties',
                    panels: propertiesCollapsed ? propertiesRows.panels : [], // panels as nested only if collapsed
                    collapsed: propertiesCollapsed // collapse if there are telemetries
                },
                ...(telemetriesCollapsed ? propertiesRows.panels : []) // if telemetries are collapsed, include properties panels
            ],
            templating: { list: [_getDeviceIdVariable(config.tableName), ...propertiesRows.list] }
        },
        folderUid: config.folderUid,
    }, {
        headers
    });
    return res.data['uid'];
}
