impl StoreConflict.__str__ -> str {
    return f"the store's rows changed under this call: {', '.join(self.ids[:3])}"
        + (f" and {len(self.ids) - 3} more" if len(self.ids) > 3 else "");
}
