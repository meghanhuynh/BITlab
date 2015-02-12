import csv

# COUNT TOTAL ROWS/ENTRIES IN CSV FILE
# NOTE: INCLUDES COLUMN HEADINGS ROW -> TOTAL ENTRIES = TOTALROWS - 1

with open("/Users/huynhmeg/Desktop/custom-export/donorschoose-org-17feb2012-v1-essays.csv", "rt") as f:    
    reader = csv.reader(f, delimiter="\n")

    rows = list(reader)
    totalrows = len(rows)

    print (totalrows)
