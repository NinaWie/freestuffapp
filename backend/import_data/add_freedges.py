import pandas as pd

freedges = pd.read_csv("data/freedges around the world - All.csv")
freedges = freedges[freedges["LABEL"] == "Freedge"]

my_cols = ["name", "description", "address", "time_posted", "photo_id", "category", "external_url", "status"]
cleaned = pd.DataFrame()
cleaned["name"] = freedges["Project"]


def compile_description(row):
    desc = ""
    details = row["Details (Describe your project)"]
    if not pd.isna(details):
        desc += details
    located = row["Location type (church, storefront, etc.)"]
    if not pd.isna(located):
        if len(desc) > 0:
            desc += "\n"
        desc += "Located at: " + located
    opening_hours = row["Days/times fridge is open"]
    if not pd.isna(opening_hours):
        if len(desc) > 0:
            desc += "\n"
        desc += "Opened: " + opening_hours
    return desc


cleaned["description"] = freedges.apply(compile_description, axis=1)
cleaned["address"] = (
    freedges["Street address"]
    + ", "
    + freedges["Zip Code"]
    + " "
    + freedges["City"]
    + ", "
    + freedges["State / Province"]
)
cleaned["time_posted"] = freedges["Date Installed"]
cleaned["photo_id"] = freedges["Image URL"]
cleaned["category"] = "Food"
cleaned["external_url"] = freedges["Main Contact (email, IG, FB, website, linktree or other)"]
cleaned["status"] = "permanent"
worldwide = cleaned.copy()

# Add foodsharing.de freedges
freedges = pd.read_csv("data/freedges around the world - foodsharing.de.csv", encoding="utf-8", delimiter=";").dropna(
    subset="freedge_name"
)

cleaned = pd.DataFrame()
cleaned["name"] = freedges["freedge_name"]
cleaned["description"] = freedges["description"] + "\n(Taken from https://foodsharing.de/)"
cleaned["address"] = freedges["address"] + ", " + freedges["zip_code"] + " " + freedges["city"]
cleaned["time_posted"] = "unknown"
cleaned["photo_id"] = ""
cleaned["category"] = "Food"
cleaned["external_url"] = freedges["link"]
cleaned["status"] = "permanent"

both_combined = pd.concat([worldwide, cleaned], ignore_index=True)
print(
    "Length of combined data:",
    len(both_combined),
    "Length of worldwide data:",
    len(worldwide),
    "Length of foodsharing.de data:",
    len(cleaned),
)
both_combined = both_combined.drop_duplicates(subset=["name", "address"], keep="first")
print("Length of combined data after dropping duplicates:", len(both_combined))
both_combined = both_combined.dropna(subset=["name", "address"], how="any")
print("Length of combined data after dropping NaN:", len(both_combined))
