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
                { date: "21.02.26", lightDay: 3917, lightNight: 1609, heating: 4.249, waterHot: 173, waterCold: 225 },
                { date: "21.01.26", lightDay: 3758, lightNight: 1554, heating: 3.555, waterHot: 170, waterCold: 221 },
                { date: "22.12.25", lightDay: 3601, lightNight: 1491, heating: 2.9183, waterHot: 166, waterCold: 216 },
                { date: "20.11.25", lightDay: 3419, lightNight: 1424, heating: 2.3118, waterHot: 162, waterCold: 210 }
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
