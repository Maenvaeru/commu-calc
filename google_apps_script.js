function doPost(e) {
    try {
        if (!e || !e.postData || !e.postData.contents) {
            return ContentService.createTextOutput(JSON.stringify({ "status": "error", "message": "No payload provided" }))
                .setMimeType(ContentService.MimeType.JSON);
        }

        var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
        var data = JSON.parse(e.postData.contents);

        var dateVal = data.date ? data.date : Utilities.formatDate(new Date(), "GMT+3", "dd.MM.yy");

        sheet.appendRow([
            dateVal,
            data.lightDay || 0,
            data.lightNight || 0,
            data.heating || 0,
            data.waterHot || 0,
            data.waterCold || 0
        ]);

        return ContentService.createTextOutput(JSON.stringify({ 
            "status": "success", 
            "timestamp": new Date().toISOString(),
            "row": sheet.getLastRow()
        })).setMimeType(ContentService.MimeType.JSON);
    } catch (err) {
        return ContentService.createTextOutput(JSON.stringify({ "status": "error", "message": err.toString() }))
            .setMimeType(ContentService.MimeType.JSON);
    }
}

function doGet(e) {
    try {
        var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
        var rows = sheet.getLastRow();

        // Если таблица пустая (нет данных)
        if (rows < 2) {
            var defaultHistory = [
                { date: "21.09.26", lightDay: 4991, lightNight: 2023, heating: 5.365, waterHot: 197, waterCold: 265 },
                { date: "21.08.26", lightDay: 4828, lightNight: 1970, heating: 5.365, waterHot: 197, waterCold: 259 },
                { date: "21.07.26", lightDay: 4670, lightNight: 1913, heating: 5.365, waterHot: 191, waterCold: 253 },
                { date: "21.06.26", lightDay: 4518, lightNight: 1841, heating: 5.365, waterHot: 188, waterCold: 247 },
                { date: "20.05.26", lightDay: 4367, lightNight: 1775, heating: 5.365, waterHot: 184, waterCold: 241 },
                { date: "22.04.26", lightDay: 4224, lightNight: 1723, heating: 5.149, waterHot: 181, waterCold: 236 },
                { date: "20.03.26", lightDay: 4054, lightNight: 1658, heating: 4.721, waterHot: 176, waterCold: 230 },
                { date: "21.02.26", lightDay: 3917, lightNight: 1609, heating: 4.249, waterHot: 173, waterCold: 225 },
                { date: "21.01.26", lightDay: 3758, lightNight: 1554, heating: 3.555, waterHot: 170, waterCold: 221 },
                { date: "22.12.25", lightDay: 3601, lightNight: 1491, heating: 2.918, waterHot: 166, waterCold: 216 }
            ];
            return ContentService.createTextOutput(JSON.stringify({
                status: "ok",
                isTemplate: true,
                history: defaultHistory,
                date: defaultHistory[0].date,
                lightDay: defaultHistory[0].lightDay,
                lightNight: defaultHistory[0].lightNight,
                heating: defaultHistory[0].heating,
                waterHot: defaultHistory[0].waterHot,
                waterCold: defaultHistory[0].waterCold
            })).setMimeType(ContentService.MimeType.JSON);
        }

        // Получаем последние записи (до 12 месяцев)
        var count = Math.min(rows - 1, 12);
        var startRow = rows - count + 1;
        var range = sheet.getRange(startRow, 1, count, 6).getValues();

        var history = [];
        for (var i = range.length - 1; i >= 0; i--) {
            var row = range[i];
            var dateStr = row[0];
            if (row[0] instanceof Date) {
                dateStr = Utilities.formatDate(row[0], "GMT+3", "dd.MM.yy");
            }
            history.push({
                date: dateStr ? dateStr.toString() : "",
                lightDay: row[1] === "" ? 0 : Number(row[1]),
                lightNight: row[2] === "" ? 0 : Number(row[2]),
                heating: row[3] === "" ? 0 : Number(row[3]),
                waterHot: row[4] === "" ? 0 : Number(row[4]),
                waterCold: row[5] === "" ? 0 : Number(row[5])
            });
        }

        var last = history[0];

        return ContentService.createTextOutput(JSON.stringify({
            status: "ok",
            history: history,
            date: last.date,
            lightDay: last.lightDay,
            lightNight: last.lightNight,
            heating: last.heating,
            waterHot: last.waterHot,
            waterCold: last.waterCold
        })).setMimeType(ContentService.MimeType.JSON);
    } catch (err) {
        return ContentService.createTextOutput(JSON.stringify({ "status": "error", "message": err.toString() }))
            .setMimeType(ContentService.MimeType.JSON);
    }
}
