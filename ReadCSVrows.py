import csv

# COUNT TOTAL ROWS/ENTRIES IN CSV FILE
# NOTE: INCLUDES COLUMN HEADINGS ROW -> TOTAL ENTRIES = TOTALROWS - 1

with open("sample-essays.csv", "rt") as f:    
    reader = csv.reader(f, delimiter=",")

    rows = list(reader)
    totalrows = len(rows)
    totalentries = totalrows - 1

    print ("Total Data Entries:", totalentries)
    
# would closing the file allow it to display all the data? 
