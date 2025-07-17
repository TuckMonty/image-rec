import React, { useState } from "react";
import { Box, Button, Input, FormLabel, VStack, useToast, Text, Image } from "@chakra-ui/react";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function QueryImage() {
  const [file, setFile] = useState(null);
  const [results, setResults] = useState([]);
  const toast = useToast();

  const handleQuery = async () => {
    if (!file) {
      toast({ title: "Please select a file.", status: "warning" });
      return;
    }
    const formData = new FormData();
    formData.append("file", file);
    formData.append("topk", 5);
    try {
    debugger    
      const res = await axios.post(`${API_URL}/query/`, formData, { headers: { "Content-Type": "multipart/form-data" } });
      setResults(res.data.matches);
      toast({ title: "Query complete!", status: "success" });
    } catch (err) {
      toast({ title: "Query failed.", status: "error" });
    }
  };

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <FormLabel>Query Image</FormLabel>
      <Input type="file" accept="image/*" onChange={e => setFile(e.target.files[0])} mb={2} />
      <Button colorScheme="green" onClick={handleQuery} mb={2}>Query Database</Button>
      {results.length > 0 && (
        <Box mt={4}>
          <Text fontWeight="bold">Top Matches:</Text>
          <VStack align="start" spacing={2} mt={2}>
            {results.map((match, idx) => (
              <Box key={idx}>
                <Text>
                  Item: {match.item_name ? `${match.item_name} (${match.item_id})` : match.item_id} | Distance: {match.distance.toFixed(4)}
                </Text>
              </Box>
            ))}
          </VStack>
        </Box>
      )}
    </Box>
  );
}
