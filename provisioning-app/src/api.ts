import axios from 'axios';

const API_VERSION = '2022-07-31';

export async function listTemplates(appUrl: string, apiKey: string): Promise<any[]> {
    const listResponse = await axios.get<{ value: any[] }>(`https://${appUrl}/api/deviceTemplates?api-version=${API_VERSION}`, {
        headers: {
            Authorization: apiKey
        }
    });
    return listResponse.data.value;
}

export async function createTables(fnUrl: string, data: any) {
    const tableResp = await axios.post(fnUrl, data, {
        headers: {
            'Content-type': 'application/json'
        }
    });
    return tableResp.data;
}