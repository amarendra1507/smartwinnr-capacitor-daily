import { SmartWinnrDaily } from 'smartwinnr-capacitor-daily';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    SmartWinnrDaily.echo({ value: inputValue })
}
