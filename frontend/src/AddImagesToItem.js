import React, { useState } from "react";
import { Box, Button, Input, FormLabel, useToast, Select, VStack, Text } from "@chakra-ui/react";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function AddImagesToItem({ items }) {
  const [selectedItem, setSelectedItem] = useState("");
  const [files, setFiles] = useState([]);
  const toast = useToast();

  const handleUpload = async () => {
    if (!selectedItem || files.length === 0) {
      toast({ title: "Please select an item and images.", status: "warning" });
      return;
    }
    try {
      for (let file of files) {
        const formData = new FormData();
        formData.append("item_id", selectedItem);
        formData.append("file", file);
        await axios.post(`${API_URL}/upload/`, formData, { headers: { "Content-Type": "multipart/form-data" } });
      }
      toast({ title: "Images added!", status: "success" });
      setFiles([]);
    } catch (err) {
      toast({ title: "Upload failed.", status: "error" });
    }
  };

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <FormLabel>Add Images to Existing Item</FormLabel>
      <Select placeholder="Select item" value={selectedItem} onChange={e => setSelectedItem(e.target.value)} mb={2}>
        {items.map(item => (
          <option key={item.item_id} value={item.item_id}>{item.item_name} ({item.item_id})</option>
        ))}
      </Select>
      <Input type="file" accept="image/*" multiple onChange={e => setFiles(Array.from(e.target.files))} mb={2} />
      <Button colorScheme="blue" onClick={handleUpload}>Add Images</Button>
      {files.length > 0 && <Text fontSize="sm" color="gray.500">{files.length} image(s) selected.</Text>}
    </Box>
  );
}
