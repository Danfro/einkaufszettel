import QtQuick 2.12

Item {
    id: root

    // list model with all
    property var categoriesModel: ListModel{}
    property var categoriesRawModel: ListModel{}
    property var categoriesList: []

    // connection details
    property string db_name: "einkauf"
    property string db_version: "1.0"
    property string db_description: "DB of Einkaufszettel app"
    property int    db_size: 1024
    property string db_table_name: "categories"

    Component.onCompleted: init()

    function db_test_callback(db){/* do nothing */}
    function init(){
        // open database
        db = Sql.LocalStorage.openDatabaseSync(db_name,db_version,db_description,db_size,db_test_callback(db))

        // create categories table if needed
        try{
            db.transaction(function(tx){
                tx.executeSql("CREATE TABLE IF NOT EXISTS "+db_table_categories+" "
                              +"(name TEXT, marked INT DEFAULT 0, deleteFlag INT DEFAULT 0, rank INT DEFAULT -1, UNIQUE(name))")
            })
        } catch (err){
            console.error("Error when creating table '"+db_table_categories+"': " + err)
        }

        // check if all necessary columns are in table
        try{
            var colnames = []
            db.transaction(function(tx){
                var rt = tx.executeSql("PRAGMA table_info("+db_table_categories+")")
                for(var i=0;i<rt.rows.length;i++){
                    colnames.push(rt.rows[i].name)
                }
            })
            // since v1.3.2: require marked column
            if (colnames.indexOf("marked")<0){
                db.transaction(function(tx){
                    tx.executeSql("ALTER TABLE "+db_table_categories+" ADD marked INT DEFAULT 0")
                })
            }
            // since v1.3.2: require deleteFlag column
            if (colnames.indexOf("deleteFlag")<0){
                db.transaction(function(tx){
                    tx.executeSql("ALTER TABLE "+db_table_categories+" ADD deleteFlag INT DEFAULT 0")
                })
            }
            // since v1.4.0: require rank column
            if (colnames.indexOf("rank")<0){
                db.transaction(function(tx){
                    tx.executeSql("ALTER TABLE "+db_table_categories+" ADD rank INT DEFAULT -1")
                })
            }
        } catch (errCols){
            console.error("Error when checking columns of table '"+db_table_categories+"': " + errCols)
        }

        // read all categories from database
        categoriesModel.clear()
        categoriesRawModel.clear()
        categoriesList = [i18n.tr("all")]
        categoriesModel.append({name:i18n.tr("all")})
        try{
            var rows = db.transaction(function(tx){tx.executeSql("SELECT * FROM "+db_table_name)})
            var resetRanks = false
            for (var i=0;i<rows.length;i++){
                // insertion sort by rank, if rank<0, then append and reset afterwards
                if (rows[i].rank<0){
                    categoriesModel.append(rows[i])
                    categoriesRawModel.append(rows[i])
                    categoriesList.push(rows[i].name)
                    resetRanks = true
                } else {
                    var j=0
                    while (j < categoriesRawModel.count &&
                           categoriesRawModel.get(j).rank < rows[i].rank &&
                           categoriesRawModel.get(j).rank > -1)
                        j++
                    categoriesModel.insert(j+1,rows[i])
                    categoriesRawModel.insert(j,rows[i])
                    categoriesList.splice(j+1,0,rows[i])
                }
            }
            // reset ranks if needed
            categoriesModel.append({name:i18n.tr("other")})
            categoriesList.push(i18n.tr("other"))
            if (resetRanks){
                for (var k=0; k<categoriesRawModel.count; k++){
                    categoriesRawModel.get(k).rank = k
                    categoriesModel.get(k+1).rank = k
                    updateRank(categoriesRawModel.get(k).name,k)
                }
            }
        } catch (e){
            console.error("Error when reading categories from database: " + e)
        }
    }
}
