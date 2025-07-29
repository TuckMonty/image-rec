import React, { useState, useEffect } from "react";
import ViewImagesModal from "./ViewImagesModal";
import { Box, Button, FormLabel, VStack, useToast, Text, Image } from "@chakra-ui/react";
import ImageUploadInput from "./ImageUploadInput";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function QueryImage() {
  const [file, setFile] = useState(null);
  const [filePreview, setFilePreview] = useState(null);
  const [results, setResults] = useState([]);
  const [selectedItem, setSelectedItem] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
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
      const res = await axios.post(`${API_URL}/query/`, formData, { headers: { "Content-Type": "multipart/form-data" } });
      setResults(res.data.matches);
      toast({ title: "Query complete!", status: "success" });
    } catch (err) {
      toast({ title: "Query failed.", status: "error" });
    }
  };

  // Show preview when file changes
  useEffect(() => {
    if (file) {
      const url = URL.createObjectURL(file);
      setFilePreview(url);
      return () => URL.revokeObjectURL(url);
    } else {
      setFilePreview(null);
    }
  }, [file]);

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <FormLabel>Find a Part</FormLabel>
      {filePreview && (
        <Box mb={2}>
          <Text fontSize="sm" color="gray.500">Query Image Preview:</Text>
          <Image src={filePreview} boxSize="120px" objectFit="cover" borderRadius="md" mb={2} />
        </Box>
      )}
      <ImageUploadInput
        id="query-image-upload"
        onChange={e => setFile(e.target.files[0])}
        file={file}
        buttonLabel="Select Image"
        changeLabel="Change Image"
      />
      <Button colorScheme="green" onClick={handleQuery} isDisabled={!file} mb={2}>Check Database</Button>
      {results.length > 0 && (
        <Box mt={4}>
          <Text fontWeight="bold">Top Matches:</Text>
          <VStack align="start" spacing={2} mt={2}>
            {results.map((match, idx) => (
              <Box
                key={idx}
                display="flex"
                alignItems="center"
                gap={3}
                _hover={{ bg: "gray.50" }}
                onClick={() => {
                  setSelectedItem({
                    item_id: match.item_id,
                    item_name: match.item_name || match.item_id,
                    meta_text: match.meta_text || ""
                  });
                  setModalOpen(true);
                }} 
                width="100%"
                cursor="pointer"
              >
                {match.preview_image && (
                  <Image src={match.preview_image} boxSize="60px" objectFit="cover" borderRadius="md" />
                )}
                  <Text>
                    Item: {match.item_name ? `${match.item_name} (${match.item_id})` : match.item_id} | Confidence: {(100 * (1 / (1 + match.distance))).toFixed(1)}%
                </Text>
              </Box>
            ))}
          </VStack>
        </Box>
      )}
      <ViewImagesModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        item={selectedItem}
      />
    </Box>
  );
}
