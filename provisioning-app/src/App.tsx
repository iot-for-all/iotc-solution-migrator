import React, { useEffect, useRef, useState } from 'react';
import './App.css';
import { DefaultButton, Spinner, SpinnerSize, TextField } from '@fluentui/react';
import { useBoolean } from '@fluentui/react-hooks';
import { createTables, listTemplates } from './api';
import Editor from '@monaco-editor/react';


function App() {
  const [appUrl, setAppUrl] = useState<string>('testappluca-m3.azureiotcentral.com');
  const [apiKey, setApiKey] = useState<string>('SharedAccessSignature sr=6f9c2a10-5110-4c36-a0cf-153dc6ae4106&sig=5qWfFIoJeF3gGmH2YIwol5nJKck1zzyQcbQr7ZrR0PE%3D&skn=Postman&se=1696431881954');
  const [fnUrl, setFnUrl] = useState<string>('https://iotcfnwtibts6jyrqbu.azurewebsites.net/api/ModelParser?code=fG-IhwVtziiwya_gisoqoA6gJPgTwynf0Jronk4hPsGqAzFuolvM2A==');
  const [result, setResult] = useState<any[]>();
  const [templatesLoading, { setTrue: startLoadingtemplates, setFalse: stopLoadingTemplates }] = useBoolean(false);

  return (
    <div className="App">
      {/* {cardState.show && (
        <div
          style={{
            position: "absolute",
            left: cardState.pagePosition?.[0],
            top: cardState.pagePosition?.[1],
            height: "100%",
          }}
        >
          <HoverCard
            expandingCardProps={expandingCardProps}
            cardDismissDelay={300}
            trapFocus
            sticky
            instantOpenOnClick
          >
            <div style={{ height: 20, width: 20 }}></div>
          </HoverCard>
        </div>
      )} */}
      <TextField label='App url' className='inputField' value={appUrl} onChange={(_, t) => setAppUrl(t!)} />
      <TextField label='Api Key' className='inputField' value={apiKey} onChange={(_, t) => setApiKey(t!)} />
      <TextField label='Function Url' className='inputField' value={fnUrl} onChange={(_, t) => setFnUrl(t!)} />
      <div className='flex space-between column height300'>
        <DefaultButton text='List templates' onClick={async () => {
          startLoadingtemplates();
          const templates = await listTemplates(appUrl!, apiKey!);
          setResult(templates);
          stopLoadingTemplates();
        }} />
        {templatesLoading && <Spinner size={SpinnerSize.small} />}
      </div>
      {result &&
        <Editor width={'70vw'} height={'90vh'} defaultLanguage='json' value={JSON.stringify(result, null, 2)} />
      }
      <DefaultButton text='Create Tables' onClick={async () => {
        await Promise.all(result!.map(async (r) => {
          await createTables(fnUrl!, r);
        }));
      }} />
    </div>
  );
}

export default App;
