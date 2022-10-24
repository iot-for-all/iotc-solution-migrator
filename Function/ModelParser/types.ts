export type DTDLDisplayName = string | {
    [language: string]: string
};

export type DTDLSchema = string | {
    "@type": string,
    fields?: {
        name: string,
        displayName: DTDLDisplayName,
        schema: string
    }[]
}

export type DTDLCapability = {
    "@id": string,
    "@type": string | string[],
    displayName: DTDLDisplayName,
    name: string,
    schema: DTDLSchema
}

export type DTDLComponent = {
    "@context": [
        "dtmi:iotcentral:context;2",
        "dtmi:dtdl:context;2"
    ],
    "@id": string,
    "@type": 'Component',
    name: string,
    schema: {
        contents: (DTDLCapability | DTDLComponent)[],
    },
    displayName: DTDLDisplayName
}

export type DTDLModel = {
    "@id": string,
    "@type": "Interface",
    contents: (DTDLCapability | DTDLComponent)[],
    displayName: DTDLDisplayName,
    "@context": [
        "dtmi:iotcentral:context;2",
        "dtmi:dtdl:context;2"
    ]
}

export type SQLDataType = 'char' | 'varchar(max)' | 'nvarchar(max)' | 'tinyint' | 'smallint' | 'int' | 'bigint' | 'float' | 'datetime';

export type SQLColumn = {
    name: string,
    displayName: string,
    dataType: SQLDataType
}
